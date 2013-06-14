define [
  'jquery'
  'underscore'
  'backbone'
  'cs!views/main'
], ($, _, Backbone, MainView) ->

  class App extends Backbone.Router

    constructor: ->
      super

    routes:
      '': 'index'
      '*actions': 'action'

    index: ->
      @currentView = new MainView()

    action: (param) ->
      console.log 'any_action', param
#      @navigate "help/troubleshooting",
#        trigger: true
#        replace: false

