$ = require 'jquery'
piano = require '../acoustic_grand_piano-ogg.js'
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
  sources: null

  activate: ->
    @context = new webkitAudioContext()
    @keys = {}
    @sources = {}
    $(document).on "keydown", (e) => @noteOn(e)
    $(document).on "keyup", (e) => @noteOff(e)
    for note, key of noteToKey
      do (key) =>
        soundData = Base64Binary.decodeArrayBuffer(piano[note].split(",")[1])
        @context.decodeAudioData soundData, (soundBuffer) => @keys[key] = soundBuffer


  keyForEvent: (event) ->
    keyCode = event.which
    firstLetter = "A".charCodeAt(0)
    lastLetter = "Z".charCodeAt(0)

    if keyCode >= firstLetter && keyCode <= LAST_NOTE
      if event.shiftKey
        index = keyCode - firstLetter + FIRST_NOTE + 12
      else
        index = keyCode - firstLetter + FIRST_NOTE
    else
      return null

    console.log majorScale
    majorScale[index]

  noteOn: (event) ->
    key = @keyForEvent(event)
    return unless key
    return if @sources[key]?.playbackState == 2

    gainNode = @context.createGainNode()
    gainNode.connect(@context.destination)
    gainNode.gain.value = 2;

    source = @context.createBufferSource()
    @sources[key] = source
    source.buffer = @keys[key]
    source.connect(gainNode);
    source.noteOn(0)

  noteOff: (event) ->
    key = @keyForEvent(event)
    return unless key

    if source = @sources[key]
      @sources[key] = null
      source.gain.linearRampToValueAtTime(1, @context.currentTime)
      source.gain.linearRampToValueAtTime(0, @context.currentTime + 0.2)
      source.noteOff(@context.currentTime + 0.3)
