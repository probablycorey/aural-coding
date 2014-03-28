Audio = require './audio.coffee'

module.exports =
  audio: null

  activate: ->
    @audio = new Audio()

  deactivate: ->
    @audio?.unsubscribe()
    @audio = null
