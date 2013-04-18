$ = require 'jquery'
piano = require '../acoustic_grand_piano-ogg'
drum = require '../synth_drum-ogg'
Base64Binary = require './base64binary'

module.exports =
  firstKey: 0x15
  lastKey: 0x6C
  noteNames: ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
  context: null
  allNoteNames: null
  keyForNoteName: null
  majorScaleNotes: null
  keys: null
  drums: null
  sources: null

  activate: ->
    @context = new webkitAudioContext()
    @keys = {}
    @drums = {}
    @sources = {}
    @keyForNoteName = {}
    @allNoteNames = [@firstKey...@lastKey].map (key) =>
      octave = Math.floor((key - 12) / 12)
      noteName = @noteNames[key % 12] + octave
      @keyForNoteName[noteName] = key
      noteName

    @majorScaleNotes = [@firstKey...@lastKey].filter (key, index) => (index % 12) in [0,2,4,5,7,9,11]

    $(document).on "keydown", (e) => @noteOn(e)
    $(document).on "keyup", (e) => @noteOff(e)

    for noteName in @allNoteNames
      do (noteName) =>
        soundData = Base64Binary.decodeArrayBuffer(piano[noteName].split(",")[1])
        @context.decodeAudioData soundData, (soundBuffer) => @keys[@keyForNoteName[noteName]] = soundBuffer

        soundData = Base64Binary.decodeArrayBuffer(drum[noteName].split(",")[1])
        @context.decodeAudioData soundData, (soundBuffer) => @drums[@keyForNoteName[noteName]] = soundBuffer

  bufferForEvent: (event) ->
    keyCode = event.which
    firstLetter = "A".charCodeAt(0)
    lastLetter = "Z".charCodeAt(0)

    if keyCode >= firstLetter && keyCode <= lastLetter
      if event.shiftKey
        index = keyCode - firstLetter + @firstKey + 12
      else
        index = keyCode - firstLetter + @firstKey
      return {buffer: @keys[@majorScaleNotes[index]]}
    else
      return {} if /meta|shift|control|alt/.test event.keystrokes
      [index, velocity] = switch event.keystrokes
        when 'backspace' then [50, 1]
        when 'delete' then [49, 1]
        when 'space' then [41, 0.025]
        when '\t' then [41]
        when '.' then [56]
        when '"' then [57]
        when '\'' then [58]
        when '+' then [61]
        when '[' then [36]
        when ']' then [37]
        when '(' then [38]
        when ')' then [39]
        when '!' then [54, 2]
        else [45]

      return {buffer: @drums[index], velocity: velocity ? 0.2}

  noteOn: (event) ->
    {buffer, velocity} = @bufferForEvent(event)
    return unless buffer
    return if @sources[event.which]?.playbackState == 2

    gainNode = @context.createGainNode()
    gainNode.connect(@context.destination)
    gainNode.gain.value = velocity;

    source = @context.createBufferSource()
    @sources[event.which] = source
    source.buffer = buffer
    source.connect(gainNode);
    source.noteOn(0)

  noteOff: (event) ->
    if source = @sources[event.which]
      @sources[event.which] = null
      source.gain.linearRampToValueAtTime(1, @context.currentTime)
      source.gain.linearRampToValueAtTime(0, @context.currentTime + 0.5)
      source.noteOff(@context.currentTime + 0.6)
