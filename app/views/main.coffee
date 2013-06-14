define [
  'jquery'
  'underscore'
  'backbone'
  'benchmark'
  'text!templates/main.html'
  'jqueryForm'
  'RaphaelFreeTransform'
  'cs!lib/settings'
  'cs!models/image-processor'
], ($, _, Backbone, Benchmark, main_html, jQueryForm, Raphael, settings, ImageProcessor) ->

  class MainView extends Backbone.View

    el:  "#content"

    template: _.template(main_html)

    events:
      'change #input_image'       : 'loadFile'
      'click #btn_test'           : 'goTest'
      'click #btn_skeleton'       : 'goDrawSkeleton'
      'click #btn_points'         : 'goDrawPoints'
      'click #btn_save'           : 'saveContour'
      'click #btn_next'           : 'zoom_next'
      'click #btn_points_no_zoom' : 'goDrawPointsNoZoom'


    initialize: () ->
      super
      @imageProcessor = new ImageProcessor
      @on 'rendered', @attach, @
      @render()


      @imageProcessor.on 'image:loaded', =>
        # we enable drawing skeleton button
        @$("#btn_skeleton").removeAttr "disabled"

      @imageProcessor.on 'done:goDrawSkeleton', =>
        @$("#btn_points").removeAttr "disabled"
        @$("#btn_skeleton").attr "disabled", "disabled"
        @$("#btn_points_no_zoom").removeAttr "disabled"

      @imageProcessor.on 'done:goDrawPoints', =>
        $("#zoom_td").show() #we show the TD that will contain the paper
        $("#btn_points").attr "disabled", "disabled"
        $("#btn_save").removeAttr "disabled"

      @imageProcessor.on 'done:zoomNext', =>
        $("#zoom_td").hide()

      @imageProcessor.on 'done:goDrawPointsNoZoom', =>
        $("#btn_points").attr "disabled", "disabled"
        $("#btn_points_no_zoom").attr "disabled", "disabled"
        $("#btn_save").removeAttr "disabled"

      @imageProcessor.on 'ajax:upload_contour', (image_name, results_to_save) =>
        $.ajax
          type: "post"
          url: "upload_contour.php"
          data:
            image_name: image_name
            json: JSON.stringify(results_to_save)
          success: @response
    goTest: () ->
      console.log 'go test', window.app
      window.app.navigate "help/troubleshooting", {trigger: true, replace: false}

    response: (response) ->
      if response is "true"
        alert "Contour saved!"
      else
        alert "Could not save the contour, please try again"

    render: () ->
      $(@el).html @template()
      @trigger 'rendered'

      $("#btn_test").removeAttr("disabled")

    attach: ()->
      @$("form").ajaxForm
        beforeSubmit: =>
          @$("#results").html "Loading..."
        success: (data) =>
          @$("#results").html ""
          @imageProcessor.parseData data

    loadFile: ()->
      console.log "load File"
#      @$('#load').trigger('click')

    goDrawSkeleton: ()->
      @imageProcessor.goDrawSkeleton()

    goDrawPoints: ()->
      @imageProcessor.goDrawPoints()

    saveContour: ()->
      @imageProcessor.saveContour()

    zoom_next: ()->
      @imageProcessor.zoomNext()

    goDrawPointsNoZoom: ()->
      @imageProcessor.goDrawPointsNoZoom()

