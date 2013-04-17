$ = require 'jquery'
instruments = require '../acoustic_grand_piano-ogg.js'
Base64Binary = require './base64binary'

module.exports =
  context: null
  piano: null
  buffer: null

  activate: ->
    @context = new webkitAudioContext()
    $(document).on "keydown", (e) => @playNote(e)
    @piano = Base64Binary.decodeArrayBuffer(instruments["A2"].split(",")[1])
    @context.decodeAudioData @piano, (buffer) =>
      @buffer = buffer

  playNote: (event) ->
    console.log "play"
    gainNode = @context.createGainNode()
    gainNode.connect(@context.destination)
    gainNode.gain.value = 1

    source = @context.createBufferSource()
    source.buffer = @buffer
    source.connect(@context.destination)
    source.connect(gainNode)
    source.noteOn(0)

    console.log source
