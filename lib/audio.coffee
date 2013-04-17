$ = require 'jquery'
piano = require '../acoustic_grand_piano-ogg'
drum = require '../synth_drum-ogg'
Base64Binary = require './base64binary'

noteToKey = {} # C8  == 108
keyToNote = {} # 108 ==  C8

FIRST_NOTE = 0x15 # first note
LAST_NOTE = 0x6C # last note

noteNames = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
for key in [FIRST_NOTE...LAST_NOTE]
  octave = Math.floor((key - 12) / 12)
  name = noteNames[key % 12] + octave
  noteToKey[name] = key
  keyToNote[key] = name

majorScalePattern = [2,2,1,2,2,2,1]
majorScaleIndex = 0
majorScale = []
key = FIRST_NOTE
while key <= LAST_NOTE
  majorScale.push(key)
  key += majorScalePattern[majorScaleIndex]
  majorScaleIndex = (majorScaleIndex + 1) % majorScalePattern.length

module.exports =
  context: null
  keys: null
  drums: null
  sources: null

  activate: ->
    @context = new webkitAudioContext()
    @keys = {}
    @drums = {}
    @sources = {}
    $(document).on "keydown", (e) => @noteOn(e)
    $(document).on "keyup", (e) => @noteOff(e)
    for note, key of noteToKey
      do (key) =>
        soundData = Base64Binary.decodeArrayBuffer(piano[note].split(",")[1])
        @context.decodeAudioData soundData, (soundBuffer) => @keys[key] = soundBuffer

        soundData = Base64Binary.decodeArrayBuffer(drum[note].split(",")[1])
        @context.decodeAudioData soundData, (soundBuffer) => @drums[key] = soundBuffer

  bufferForEvent: (event) ->
    keyCode = event.which
    firstLetter = "A".charCodeAt(0)
    lastLetter = "Z".charCodeAt(0)

    if keyCode >= firstLetter && keyCode <= lastLetter
      if event.shiftKey
        index = keyCode - firstLetter + FIRST_NOTE + 12
      else
        index = keyCode - firstLetter + FIRST_NOTE
      return {buffer: @keys[majorScale[index]]}
    else
      return {} if /meta|shift|control|alt/.test event.keystrokes
      [index, velocity] = switch event.keystrokes
        when 'backspace' then [49, 1]
        when 'delete' then [50, 1]
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
