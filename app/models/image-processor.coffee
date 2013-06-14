define [
  'underscore'
  'backbone'
  'benchmark'
  'cs!lib/settings'
  'cs!lib/point'
], (_, Backbone, Benchmark, settings, point) ->

  ###

  Base class to work with the data (without renderings)

  ###

  class ImageProcessor extends Backbone.Model

    initialize: () ->
      #param for benchmarkTest
      @benchmarkOptions =
        maxTime: 0.5

      @suite = new Benchmark.Suite
      @benchmarkTestObj = {}

    constructor: ()->
      super
      @on 'change:data', @loadImage, @
      @on 'image:loaded', @showBoundingBox, @
      @on 'created:boundingBox', @scaleBodyContour, @
      @on 'done:bodyContour', @drawInitialBodyContour, @

    benchmarkTest: (name, fn, params) ->
      if !@benchmarkTestObj[name]
        @benchmarkTestObj[name] = true
        @suite.add(name, =>
          fn
        , @benchmarkOptions).on("cycle", (event) ->
          console.log String(event.target)
        ).run()

    parseData: (data)->
      @set('data', data) if data?

    getR: ->
      return @r if @r?
      @r = Raphael(
        'holder'
        @width
        @height
      )

    getR2: ->
      return @r2 if @r2?
      @r2 = Raphael(
        'holder2'
        settings.zoomed_paper_width
        settings.zoomed_paper_height
      )

    loadImage: ->
      data = @get 'data'
      if /error/.test data
        return @trigger 'error', 'Could not save the image, please try again'
      parts = data.split(";")
      @image_link = parts[0]
      @image_name = parts[0].split("/")[1]
      originial_width = parts[1].split("-")[0]
      originial_height = parts[1].split("-")[1]
      @height = settings.image_height
      @width = @height * originial_width / originial_height
      r = @getR()
      r.setViewBox 0, 0, r.width, r.height
      @image = r.image(@image_link, 0, 0, @width, @height)
      @trigger 'image:loaded', {@width, @height}


    showBoundingBox: ->
      # we use the offsets in settings modules
      x0 = @width * settings.boundingBox_x
      y0 = @height * settings.boundingBox_y
      width = @width * settings.boundingBox_width
      height = @height * settings.boundingBox_height
      # TODO: this.r = new Raphael ...
      @boundingBox = @getR().rect(x0, y0, width, height)
      @boundingBox.attr
        fill: settings.boundingBox_fill
        stroke: settings.boundingBox_stroke
        "fill-opacity": settings.boundingBox_fill_opacity
        "stroke-width": settings.boundingBox_stroke_width
        "stroke-opacity": settings.boundingBox_stroke_opacity
        cursor: "move"
      @trigger 'created:boundingBox'

    ###
    Function for scaling Body Contour
    ###
    scaleBodyContour: ->
      getBbox = @boundingBox.getBBox()
      templateBodyContour = point.getTemplateBodyContour()
      # resulting coordinates
      @results = templateBodyContour.map (item) =>
        x: Math.round(item.x * getBbox.width)  + Math.round(getBbox.x)
        y: Math.round(item.y * getBbox.height) + Math.round(getBbox.y)
      @trigger 'done:bodyContour'


    pointsToPath: ->
      cSize = @results.length
      [x0, y0] = [@results[0].x, @results[0].y]
      s = ["M", x0, ",", y0, "R", @results[1].x, ",", @results[1].y].join('')
      s_path = []
      i = 0
      while i < cSize - 1
        s_path.push @results[i].x, @results[i].y
        i = i + 16
      s_path = ["M", x0, y0, "R"].concat(s_path)
      s_path.push "Z"
      path = @getR().path(s_path)
      path.attr
        stroke: settings.bodyContour_stroke
        "stroke-width": settings.bodyContour_stroke_width
        "stroke-opacity": settings.bodyContour_stroke_opacity
        "stroke-dasharray": settings.bodyContour_stroke_dasharray
      path

    drawInitialBodyContour: ->
      path = @pointsToPath()
      @bodyContour = @getR().set(@boundingBox, path)
      options =
        distance: 1
        rotate: [null, null, null]
        draw: "bbox"

      @ft = @getR().freeTransform(@bodyContour, options)
      @ft.hideCenterAndLines()

    getLines: (index) ->
      results = []
      i = 0
      while i < @lines.length
        if @lines[i].from is index or @lines[i].to is index
          results.push @lines[i]
          @lines.splice i, 1
          i--
        i++
      results



    # DrawSkeleton

    scaleSkeleton: ->
      boundingBox = @bodyContour.items[0]
      templateJoints = point.getTemplateJoints()
      templateJoints.map (item) =>
        x: item.x * boundingBox.getBBox().width  + boundingBox.getBBox().x
        y: item.y * boundingBox.getBBox().height + boundingBox.getBBox().y


    drawSkeleton : (results) ->

      #we draw the lines between the joints
      #drawLine takes two parameters : the index of the first joint
      #in joints array
      #and the index of the second
      @lines = []
      @joints = []
      self = this
      @drawLine results, 0, 1
      @drawLine results, 1, 2
      @drawLine results, 2, 3
      @drawLine results, 3, 4
      @drawLine results, 1, 5
      @drawLine results, 5, 6
      @drawLine results, 6, 7
      @drawLine results, 2, 11
      @drawLine results, 5, 8
      @drawLine results, 8, 11
      @drawLine results, 8, 9
      @drawLine results, 9, 10
      @drawLine results, 11, 12
      @drawLine results, 12, 13

      #we draw the joints and implement the behaviour we want to have
      #on dragging
      results.forEach (result, i) =>
        dot = self.getR().circle(result.x, result.y, 2)
        dot.attr
          fill: settings.joints_fill
          stroke: settings.joints_stroke
          "fill-opacity": settings.joints_fill_opacity
          "stroke-width": settings.joints_stroke_width

        dot.joint_index = i #we store the index of the joint in joints array
        #to be used later
        dot.original_location =
          x: result.x
          y: result.y

        dot.mousedown ->
          @original_location =
            x: @attr("cx")
            y: @attr("cy")

          self.tmpContour = self.clone(self.results)

        dot.drag ((dx, dy) ->
          att = #updated coordinates
            cx: @ox + dx
            cy: @oy + dy

          @attr att

          #we need to remove the lines connected to this joint
          lines = self.getLines(@joint_index) #get related lines
          lines.forEach (line) ->
            line.remove()

          #update the dragged joint coordinates in joints array
          results[@joint_index].x = @ox + dx
          results[@joint_index].y = @oy + dy

          #we draw new lines connecting this joints to the others
          res = self.getRelatedJointsIndexes(@joint_index)
          res.forEach (item) =>
            self.drawLine results, @joint_index, item

          #we move the contour
          self.moveContours(
            @joint_index
            @original_location
            self.joints[@joint_index]
          )
          self.joints.forEach (joint) ->
            joint.toFront
        ), ->
          @ox = @attr("cx")
          @oy = @attr("cy")

        self.joints.push dot

      self.joints.forEach (joint) ->
        joint.toFront

    clone: (activeBodyContour) ->
      activeBodyContour.map (item) =>
        x: @getX(item)
        y: @getY(item)


    goDrawSkeleton: ->
      @bodyContour.hide()
      scaling_results = @scaleSkeleton()
      @drawSkeleton scaling_results
      @scale = 1
      @PathToPoints()
      @cIndex = point.getTemplateBodyContourIndex()
      @ft.hideHandles()
      @trigger 'done:goDrawSkeleton'




    PathToPoints: ->
      r = @getR()
      path = @bodyContour.items[1]
      s = path.matrix.toTransformString()

      #we need to apply all the transformations that have been made on
      #the path to get the right coordinates
      @results = @results.map (result, i) =>
        #tmp is a temporary circle used to get real coordinates
        tmp = r.circle(result.x, result.y, 1)
        tmp.transform s
        tmp.hide()
        realX = tmp.matrix.x(tmp.attr("cx"), tmp.attr("cy"))
        realY = tmp.matrix.y(tmp.attr("cx"), tmp.attr("cy"))
        result.x = realX
        result.y = realY
        @dragged = false
        [x, y] = [result.x, result.y]
        c = @getR().circle(x, y, settings.bodyContour_point_radius)
        c.x = x
        c.y = y
        c.index = i
        c.attr
          fill: settings.bodyContour_fill
          stroke: settings.bodyContour_stroke
          "fill-opacity": settings.bodyContour_fill_opacity
          "stroke-width": settings.bodyContour_stroke_width

        c.click (e) ->
          unless self.dragged
            @animate
              r: 5
              fill: settings.bodyContour_fill_animated
            , 10
            unless self.selected_point1?
              self.selected_point1 = this
              self.selected_point1.x = e.layerX
              self.selected_point1.y = e.layerY
            else unless self.selected_point2?
              self.selected_point2 = this
              self.selected_point2.x = e.layerX
              self.selected_point2.y = e.layerY
              if self.selected_point1.index > self.selected_point2.index
                tmp = self.selected_point1
                self.selected_point1 = self.selected_point2
                self.selected_point2 = tmp
              highlightCriticalPoints false
            else
              unhighlightCriticalPoints false
              self.selected_point1.animate
                r: 1
              , 200
              self.selected_point2.animate
                r: 1
              , 200
              self.selected_point1.remove()
              self.selected_point2.remove()
              self.selected_point2 = null
              self.selected_point1 = this
              self.selected_point1.x = e.layerX
              self.selected_point1.y = e.layerY
            self.toFront()
          else
            self.dragged = false
        return c  # push c to @results

      @toFront()


    toFront: ->
      @results.forEach (item) ->
        item.toFront()

    highlightCriticalPoints: (zoomed) ->
      activeBodyContour = (if not zoomed then @results else @zoomed_results)
      @mouseovers = []
      @mouseouts = []
      radius = (if not zoomed then settings.bodyContour_point_radius
      else settings.bodyContour_point_radius_zoomed)
      direction = @getDirection(@selected_point1, @selected_point2)
      index1 = @selected_point1.index
      index2 = @selected_point2.index
      if direction is "0"
        i = index1 + 1
        while i < index2
          handle i, radius, activeBodyContour, direction
          i++
      else
        i = index2 + 11
        len = @results.length

        while i < len
          handle i, radius, activeBodyContour, direction
          i++
        i = 0
        while i < index1
          handle i, radius, activeBodyContour, direction
          i++

    getDirection: (point1, point2) ->
      total_length = @results.length
      t1 = point2.index - point1.index
      t2 = total_length - point2.index + point1.index
      (if t1 > t2 then "1" else "0")

    handle: (i, radius, activeBodyContour, direction) ->
      mouseover = (event) ->
        @animate
          r: radius * 5
        , 10
        @attr
          fill: settings.bodyContour_critical_fill
          stroke: settings.bodyContour_critical_stroke
          "fill-opacity": settings.bodyContour_critical_fill_opacity
          "stroke-width": settings.bodyContour_critical_stroke_width


      @mouseovers.push mouseover
      mouseout = (event) ->
        @animate
          r: radius
        , 10
        @attr
          fill: settings.bodyContour_fill
          stroke: settings.bodyContour_stroke
          "fill-opacity": settings.bodyContour_fill_opacity
          "stroke-width": settings.bodyContour_stroke_width


      @mouseouts.push mouseout
      activeBodyContour[i].hover mouseover, mouseout
      activeBodyContour[i].drag ((dx, dy) ->
        dx = dx * @scale
        dy = dy * @scale
        @dragged = true
        @animate
          r: radius * 5
        , 10
        @attr
          fill: settings.bodyContour_critical_fill
          stroke: settings.bodyContour_critical_stroke
          "fill-opacity": settings.bodyContour_critical_fill_opacity
          "stroke-width": settings.bodyContour_critical_stroke_width


        #check if selected_point1 is before selected_point2
        if @selected_point1.index > @selected_point2.index
          tmp = @selected_point1
          @selected_point1 = @selected_point2
          @selected_point2 = tmp
        att = #updated coordinats
          cx: @ox + dx
          cy: @oy + dy

        x = @ox + dx
        y = @oy + dy

        if direction is "0"
          @calculateNewCoordinates activeBodyContour, @selected_point1.index, @index, this, activeBodyContour[@selected_point1.index],
            x: x
            y: y

          @calculateNewCoordinates activeBodyContour, @index, @selected_point2.index, this, activeBodyContour[@selected_point2.index],
            x: x
            y: y

        else
          @calculateNewCoordinates activeBodyContour, @selected_point2.index, @index, this, activeBodyContour[@selected_point2.index],
            x: x
            y: y

          @calculateNewCoordinates activeBodyContour, @index, @selected_point1.index, this, activeBodyContour[@selected_point1.index],
            x: x
            y: y

        @attr att
        @toFront()
      ), (->
        @ox = @attr("cx")
        @oy = @attr("cy")
      ), (event) ->
        @animate
          r: radius
        , 10
        @moveContours attr
          fill: settings.bodyContour_fill
          stroke: settings.bodyContour_stroke
          "fill-opacity": settings.bodyContour_fill_opacity
          "stroke-width": settings.bodyContour_stroke_width

    calculateNewCoordinates: (idx, p1, p2) ->
      activeBodyContour = @results
      tmpContour = @tmpContour
      cIndex = @cIndex
      diff = {} #for wrist and ankle movements
      diff.x = @getX(p1) - @getX(p2)
      diff.y = @getY(p1) - @getY(p2)
      i = cIndex[idx]
      len = cIndex[idx + 1]

      while i < len
        tmpx = @getX(tmpContour[i])
        tmpx -= diff.x
        tmpy = @getY(tmpContour[i])
        tmpy -= diff.y
        activeBodyContour[i].attr
          cx: tmpx
          cy: tmpy

        i++

    ###
    function for calculating coordinates type1
    @param {int} [idx]
    @param {element/object} [p1]
    @param {element/object} [p2]
    ###
    calculateNewCoordinates1: (idx, p1, p2) ->
      activeBodyContour = @results
      tmpContour = @tmpContour
      cIndex = @cIndex
      diff = {} #for wrist and ankle movements
      diff.x = @getX(p1) - @getX(p2)
      diff.y = @getY(p1) - @getY(p2)
      i = cIndex[idx]
      len = cIndex[idx + 1]

      while i < len
        tmpx = @getX(tmpContour[i])
        tmpx -= diff.x
        tmpy = @getY(tmpContour[i])
        tmpy -= diff.y
        activeBodyContour[i].attr
          cx: tmpx
          cy: tmpy

        i++

    ###
    function for calculating coordinates type2
    @param {int} [idx]
    @param {element/object} [p1]
    @param {element/object} [p2]
    @param {element/object} [p3]
    ###
    calculateNewCoordinates2: (idx, p1, p2, p3) ->
      activeBodyContour = @results
      tmpContour = @tmpContour
      cIndex = @cIndex
      t = {}
      v = {}
      p12 = {}
      p32 = {}
      sIndx = idx % cIndex.length
      eIndex = (idx + 1) % cIndex.length
      lenght = Math.abs(cIndex[eIndex] - cIndex[sIndx])
      tSize = activeBodyContour.length
      p12.x = @getX(p1) - @getX(p2)
      p12.y = @getY(p1) - @getY(p2)
      p32.x = @getX(p3) - @getX(p2)
      p32.y = @getY(p3) - @getY(p2)
      denam = p12.x * p12.x + p12.y * p12.y
      lenght = tSize - lenght  if lenght > tSize / 2
      i = 0
      while i < lenght
        idx_ = (i + cIndex[sIndx]) % tSize
        t = tmpContour[idx_]
        v.x = (@getX(t) - @getX(p2)) * p12.x + (@getY(t) - @getY(p2)) * p12.y
        v.y = (@getY(t) - @getY(p2)) * p12.x - (@getX(t) - @getX(p2)) * p12.y
        v.x = v.x / denam
        v.y = v.y / denam
        tmpx = @getX(p2) + v.x * p32.x - v.y * p32.y
        tmpy = @getY(p2) + v.x * p32.y + v.y * p32.x
        activeBodyContour[idx_].attr
          cx: tmpx
          cy: tmpy

        i++

    ###
    function for calculating coordinates type3
    @param {element/object} [p1]
    @param {element/object} [p2]
    @param {element/object} [p3]
    @param {element/object} [control_point]
    ###
    calculateNewCoordinates3: (p1, p2, p3, control_point) ->
      tmpContour = @tmpContour
      t = {}
      v = {}
      p12 = {}
      p32 = {}
      p12.x = @getX(p1) - @getX(p2)
      p12.y = @getY(p1) - @getY(p2)
      p32.x = @getX(p3) - @getX(p2)
      p32.y = @getY(p3) - @getY(p2)
      denam = p12.x * p12.x + p12.y * p12.y
      t = tmpContour[control_point]
      v.x = (@getX(t) - @getX(p2)) * p12.x + (@getY(t) - @getY(p2)) * p12.y
      v.y = (@getY(t) - @getY(p2)) * p12.x - (@getX(t) - @getX(p2)) * p12.y
      v.x = v.x / denam
      v.y = v.y / denam
      return {
        x: @getX(p2) + v.x * p32.x - v.y * p32.y
        y: @getY(p2) + v.x * p32.y + v.y * p32.x
      }


    ###
    function for getting x coordinate from a Raphael element/object(x,y)
    @param {object/element} [element]
    @return {number}  x coordinate
    ###
    getX: (element) ->
      if _.isFunction(element.attr)
        element.attr "cx"
      else
        element.x

    ###
    function for getting y coordinate from a Raphael element/object(x,y)
    @param {object/element} [element]
    @return {number}  y coordinate
    ###
    getY: (element) ->
      if _.isFunction(element.attr)
        element.attr "cy"
      else
        element.y

    ###
    get related joints
    @param {int} [index] joint index
    @return {array} [results] related indexes
    ###
    getRelatedJointsIndexes: (index) ->
      switch index
        when 0  then [1]
        when 1  then [0, 2, 5]
        when 2  then [1, 3, 11]
        when 3  then [2, 4]
        when 4  then [3]
        when 5  then [1, 6, 8]
        when 6  then [5, 7]
        when 7  then [6]
        when 8  then [5, 11, 9]
        when 9  then [8, 10]
        when 10 then [9]
        when 11 then [2, 12, 8]
        when 12 then [11, 13]
        when 13 then [12]



    moveContours : (index, dragged_joint, dragged_to) ->
      activeBodyContour = @results
      tmpContour = @tmpContour
      cIndex = @cIndex

      if index is 0
        control_point = @calculateNewCoordinates3(dragged_joint, activeBodyContour[cIndex[25]], dragged_to, cIndex[0])
        @calculateNewCoordinates2 25, tmpContour[cIndex[0]], activeBodyContour[cIndex[25]], control_point
        @calculateNewCoordinates2 0, tmpContour[cIndex[0]], activeBodyContour[cIndex[1]], control_point

      #left shoulder
      if index is 2
        control_point = @calculateNewCoordinates3(dragged_joint, activeBodyContour[cIndex[1]], dragged_to, cIndex[2])
        @calculateNewCoordinates2 1, tmpContour[cIndex[2]], activeBodyContour[cIndex[1]], control_point
        @calculateNewCoordinates2 2, tmpContour[cIndex[2]], activeBodyContour[cIndex[3]], control_point

      #right shoulder
      if index is 5
        control_point = @calculateNewCoordinates3(dragged_joint, activeBodyContour[cIndex[25]], dragged_to, cIndex[24])
        @calculateNewCoordinates2 23, tmpContour[cIndex[24]], activeBodyContour[cIndex[23]], control_point
        @calculateNewCoordinates2 24, tmpContour[cIndex[24]], activeBodyContour[cIndex[25]], control_point

      #left ankle
      if index is 10
        @calculateNewCoordinates2 9, dragged_joint, activeBodyContour[cIndex[9]], dragged_to
        @calculateNewCoordinates1 10, dragged_joint, dragged_to
        @calculateNewCoordinates2 11, dragged_joint, activeBodyContour[cIndex[12]], dragged_to

      #right ankle
      if index is 13
        @calculateNewCoordinates2 14, dragged_joint, activeBodyContour[cIndex[14]], dragged_to
        @calculateNewCoordinates1 15, dragged_joint, dragged_to
        @calculateNewCoordinates2 16, dragged_joint, activeBodyContour[cIndex[17]], dragged_to

      #left elbow
      if index is 3
        control_point = @calculateNewCoordinates3(dragged_joint, activeBodyContour[cIndex[2]], dragged_to, cIndex[3])
        @calculateNewCoordinates2 2, tmpContour[cIndex[3]], activeBodyContour[cIndex[2]], control_point
        @calculateNewCoordinates2 3, tmpContour[cIndex[3]], activeBodyContour[cIndex[4]], control_point
        control_point = @calculateNewCoordinates3(dragged_joint, activeBodyContour[cIndex[7]], dragged_to, cIndex[6])
        @calculateNewCoordinates2 5, tmpContour[cIndex[6]], activeBodyContour[cIndex[5]], control_point
        @calculateNewCoordinates2 6, tmpContour[cIndex[6]], activeBodyContour[cIndex[7]], control_point

      #left wrist
      if index is 4
        @calculateNewCoordinates1 4, dragged_joint, dragged_to
        @calculateNewCoordinates2 3, dragged_joint, activeBodyContour[cIndex[3]], dragged_to
        @calculateNewCoordinates2 5, dragged_joint, activeBodyContour[cIndex[6]], dragged_to

      #right elbow
      if index is 6
        control_point = @calculateNewCoordinates3(dragged_joint, activeBodyContour[cIndex[19]], dragged_to, cIndex[20])
        @calculateNewCoordinates2 19, tmpContour[cIndex[20]], activeBodyContour[cIndex[19]], control_point
        @calculateNewCoordinates2 20, tmpContour[cIndex[20]], activeBodyContour[cIndex[21]], control_point
        control_point = @calculateNewCoordinates3(dragged_joint, activeBodyContour[cIndex[24]], dragged_to, cIndex[23])
        @calculateNewCoordinates2 22, tmpContour[cIndex[23]], activeBodyContour[cIndex[22]], control_point
        @calculateNewCoordinates2 23, tmpContour[cIndex[23]], activeBodyContour[cIndex[24]], control_point

      #right wrist
      if index is 7
        @calculateNewCoordinates1 21, dragged_joint, dragged_to
        @calculateNewCoordinates2 20, dragged_joint, activeBodyContour[cIndex[20]], dragged_to
        @calculateNewCoordinates2 22, dragged_joint, activeBodyContour[cIndex[23]], dragged_to

      #left hips
      if index is 8
        control_point = @calculateNewCoordinates3(dragged_joint, activeBodyContour[cIndex[7]], dragged_to, cIndex[8])
        @calculateNewCoordinates2 7, tmpContour[cIndex[8]], activeBodyContour[cIndex[7]], control_point
        @calculateNewCoordinates2 8, tmpContour[cIndex[8]], activeBodyContour[cIndex[9]], control_point

      #right hips
      if index is 11
        control_point = @calculateNewCoordinates3(dragged_joint, activeBodyContour[cIndex[19]], dragged_to, cIndex[18])
        @calculateNewCoordinates2 17, tmpContour[cIndex[18]], activeBodyContour[cIndex[17]], control_point
        @calculateNewCoordinates2 18, tmpContour[cIndex[18]], activeBodyContour[cIndex[19]], control_point

      #right foot
      if index is 9
        control_point = @calculateNewCoordinates3(dragged_joint, activeBodyContour[cIndex[8]], dragged_to, cIndex[9])
        @calculateNewCoordinates2 8, tmpContour[cIndex[9]], activeBodyContour[cIndex[8]], control_point
        @calculateNewCoordinates2 9, tmpContour[cIndex[9]], activeBodyContour[cIndex[10]], control_point
        control_point = @calculateNewCoordinates3(dragged_joint, activeBodyContour[cIndex[13]], dragged_to, cIndex[12])
        @calculateNewCoordinates2 11, tmpContour[cIndex[12]], activeBodyContour[cIndex[11]], control_point
        @calculateNewCoordinates2 12, tmpContour[cIndex[12]], activeBodyContour[cIndex[13]], control_point

      #left foot
      if index is 12
        control_point = @calculateNewCoordinates3(dragged_joint, activeBodyContour[cIndex[13]], dragged_to, cIndex[14])
        @calculateNewCoordinates2 13, tmpContour[cIndex[14]], activeBodyContour[cIndex[13]], control_point
        @calculateNewCoordinates2 14, tmpContour[cIndex[14]], activeBodyContour[cIndex[15]], control_point
        control_point = @calculateNewCoordinates3(dragged_joint, activeBodyContour[cIndex[16]], dragged_to, cIndex[17])
        @calculateNewCoordinates2 16, tmpContour[cIndex[17]], activeBodyContour[cIndex[16]], control_point
        @calculateNewCoordinates2 17, tmpContour[cIndex[17]], activeBodyContour[cIndex[18]], control_point

    drawLine: (results, index1, index2) ->
      [r1, r2] = [results[index1], results[index2]]
      [x1, y1, x2, y2] = [r1.x, r1.y, r2.x, r2.y]
      s =  ['M', x1, ',', y1, 'L', x2, ',', y2].join('')
      line = @getR().path(s)
      line.attr
        stroke: settings.lines_stroke
        "stroke-width": settings.lines_stroke_width
        cursor: "move"
        "stroke-dasharray": settings.lines_stroke_dasharray

      line.from = index1
      line.to = index2
      @lines.push line

    goDrawPoints: ->
      @lock()
      @zoomEditLoad()
      @hideSkeleton()
      @trigger 'done:goDrawPoints'

    hideSkeleton: ->
      @lines.forEach (line) ->
        line.remove()
      @joints.forEach (joint) ->
        joint.remove()

    zoomEditLoad: ->
      height = settings.zoomed_image_height
      width = height * @image.attr("width") / @image.attr("height")
      @image2 = @getR2().image(@image.attr("src"), 0, 0, width, height)
      #the bodyContour could had been altered while moving the joints
      @bbox = @calculateBodyBoundingBox()
      #so we need to calculate the bounding box again
      @drawZoomedContour()
      @current_zoom = "head"


    ###
    function for locking the main paper
    ###
    lock : ->
      #we draw a rect having the same dimension as the paper
      #with fill-opacity=0 to make it transparent
      @lock = @getR().rect(0, 0, @getR().width, @getR().height)
      @lock.attr
        fill: "#FFF"
        "fill-opacity": 0


    calculateBodyBoundingBox: ->
      minX = maxX = @results[0].attr("cx")
      minY = maxY = @results[0].attr("cy")

      @results.forEach (item) ->
        if item.attr("cx") < minX
          minX = item.attr("cx")
        else maxX = item.attr("cx")  if item.attr("cx") > maxX
        if item.attr("cy") < minY
          minY = item.attr("cy")
        else maxY = item.attr("cy")  if item.attr("cy") > maxY

      kx = @image2.attr("width")  / @image.attr("width")
      ky = @image2.attr("height") / @image.attr("height")

      return {
        x      : minX * kx
        y      : minY * ky
        width  : bbox.x * kx
        height : bbox.y * ky
      }

    drawZoomedContour: ->
      self = this
      r2 = @getR2()
      image_width = @image.attr("width")
      image_height = @image.attr("height")
      current_width = @image2.attr("width")
      current_height = @image2.attr("height")

      @zoomed_results = @results.map (result, i) =>
        #for each point we calculate the new coordinates
        newX = result.attr("cx") * current_width / image_width
        newY = result.attr("cy") * current_height / image_height
        c = r2.circle(newX, newY, settings.bodyContour_point_radius_zoomed)
        c.index = i
        c.attr
          fill: settings.bodyContour_fill
          stroke: settings.bodyContour_stroke
          "fill-opacity": settings.bodyContour_fill_opacity
          "stroke-width": settings.bodyContour_stroke_width

        @dragged = false
        c.click (e) ->
          unless self.dragged
            @animate
              r: settings.bodyContour_selected_point_zoomed_radius
              fill: settings.bodyContour_fill_animated
            , 10
            unless self.selected_point1?
              self.selected_point1 = this
              self.selected_point1.x = e.layerX
              self.selected_point1.y = e.layerY
            else unless self.selected_point2?
              self.selected_point2 = this
              self.selected_point2.x = e.layerX
              self.selected_point2.y = e.layerY

              #we need to have selected_point1 before selected_point2
              if self.selected_point1.index > self.selected_point2.index
                tmp = self.selected_point1
                self.selected_point1 = self.selected_point2
                self.selected_point2 = tmp

              #we make the points between selected_point1
              #and selected_point2 draggable
              self.highlightCriticalPoints true
            #if both selected_point1 and selected_point2
            #have been selected=> this is a new selection
            else
              unhighlightCriticalPoints true
              self.selected_point1.animate
                r: settings.bodyContour_point_radius_zoomed
              , 10
              self.selected_point2.animate
                r: settings.bodyContour_point_radius_zoomed
              , 10
              self.selected_point1.attr
                fill: settings.bodyContour_fill
                stroke: settings.bodyContour_stroke
                "fill-opacity": settings.bodyContour_fill_opacity
                "stroke-width": settings.bodyContour_stroke_width

              self.selected_point2.attr
                fill: settings.bodyContour_fill
                stroke: settings.bodyContour_stroke
                "fill-opacity": settings.bodyContour_fill_opacity
                "stroke-width": settings.bodyContour_stroke_width

              self.selected_point2 = null
              self.selected_point1 = this
              self.selected_point1.x = e.layerX
              self.selected_point1.y = e.layerY
            self.toFront()
          else
            self.dragged = false

        return c #push to @results

      self.toFront()

    #-----------------------
    saveContour: ->
      contour = @results
      results_to_save = []
      height = @image.attr("height")
      width = @image.attr("width")
      normalized_height = 1000
      normalized_width = normalized_height * width / height
      i = 0
      len = contour.length

      while i < len
        results_to_save[i] = {}
        results_to_save[i].x = contour[i].attr("cx") * normalized_width /width
        results_to_save[i].y = contour[i].attr("cy") * normalized_height /height
        i++
      @trigger 'ajax:upload_contour', @image_name, results_to_save

    #-------------------------------------
    zoomNext: ->
      #fromZoom();
      switch @current_zoom
        when "head"
          @current_zoom = "shoulders"
          @showShoulders()
          break
        when "shoulders"
          @current_zoom = "left_arm"
          @showArm "left"
          break
        when "left_arm"
          @current_zoom = "right_arm"
          @showArm "right"
          break
        when "right_arm"
          @current_zoom = "arm_tip_to_hip"
          @showArmTipToHip()
          break
        when "arm_tip_to_hip"
          @current_zoom = "end"
          @showLegs()
          break
        when "end"
          @fromZoom()
          alert "Zooming done"
          @getR2().remove()
          break


    showShoulders: ->
      bbox = @bbox
      ratio = 0.98
      vw = bbox.width * ratio
      vh = vw
      bbox_center_x = bbox.x + bbox.width / 2
      vx = bbox_center_x - (vw) / 2
      vy = bbox.y + bbox.height * 0.10
      @scale = vw / settings.zoomed_paper_width
      @getR2().setViewBox vx, vy, vw, vh

    showHead: ->
      bbox = @bbox
      ratio = 0.65
      head_offset = 12
      vw = bbox.width * ratio
      vh = vw
      bbox_center_x = bbox.x + bbox.width / 2
      vx = bbox_center_x - (vw) / 2
      vy = bbox.y - head_offset
      #usefull later for adjusting drag
      @scale = vw / settings.zoomed_paper_width
      @getR2().setViewBox vx, vy, vw, vh

    showArm: (arm) ->
      bbox = @bbox
      ratio = 0.45
      vh = bbox.height * ratio
      vw = vh
      if arm is "left"
        vx = bbox.x - vw / 2
      else
        vx = bbox.x + bbox.width - vw / 2
      vy = bbox.y + bbox.height * 0.15
      @scale = vw / settings.zoomed_paper_width
      @getR2().setViewBox vx, vy, vw, vh

    showArmTipToHip: ->
      bbox = @bbox
      ratio = 0.30
      vh = bbox.height * ratio
      vw = vh
      bbox_center_x = bbox.x + bbox.width / 2
      vx = bbox_center_x - (vw) / 2
      vy = bbox.y + bbox.height * 0.20
      @scale = vw / settings.zoomed_paper_width
      @getR2().setViewBox vx, vy, vw, vh

    showLegs: ->
      bbox = @bbox
      ratio = 0.65
      vh = bbox.height * ratio
      vw = vh
      bbox_center_x = bbox.x + bbox.width / 2
      vx = bbox_center_x - (vw) / 2
      vy = bbox.y + bbox.height * 0.35
      @scale = vw / settings.zoomed_paper_width
      @getR2().setViewBox vx, vy, vw, vh

    fromZoom: ->


    goDrawPointsNoZoom: ->
      @hideSkeleton()
      @trigger 'done:goDrawPointsNoZoom'

