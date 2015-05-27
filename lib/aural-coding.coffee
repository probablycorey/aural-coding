Base64Binary = require '../vendor/base64binary'
piano = require '../vendor/acoustic_grand_piano-ogg'
drum = require '../vendor/synth_drum-ogg'

module.exports =
class AuralCoding
  constructor: ->
    @firstKey = 0x15
    @lastKey = 0x6C
    @noteNames = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
    @context = new AudioContext()
    @keys = {}
    @drums = {}
    @sources = {}
    @keyForNoteName = {}
    @noteForKey = {}
    @allNoteNames = []

    for key in [@firstKey...@lastKey]
      octave = Math.floor((key - 12) / 12)
      noteName = @noteNames[key % 12] + octave
      @allNoteNames.push noteName
      @keyForNoteName[noteName] = key
      @noteForKey[key] = noteName

    @majorScaleNotes = [@firstKey...@lastKey].filter (key, index) =>
      ((index + 4) % 12) in [0,2,4,5,7,9,11] # C Major Scale. (I think?)

    atom.views.getView(atom.workspace).addEventListener 'keydown', (e) => @noteOn(e)
    atom.views.getView(atom.workspace).addEventListener 'onkeyup', (e) => @noteOff(e)

    for noteName in @allNoteNames
      do (noteName) =>
        soundData = Base64Binary.decodeArrayBuffer(piano[noteName].split(",")[1])
        @context.decodeAudioData soundData, (soundBuffer) => @keys[@keyForNoteName[noteName]] = soundBuffer

        soundData = Base64Binary.decodeArrayBuffer(drum[noteName].split(",")[1])
        @context.decodeAudioData soundData, (soundBuffer) => @drums[@keyForNoteName[noteName]] = soundBuffer

  bufferForEvent: (key, modifiers) ->
    return unless key

    if /^[a-z]$/i.test key
      keyCode = key.toUpperCase().charCodeAt(0)
      index = 24 + (keyCode - 'A'.charCodeAt(0)) % 12
      index += 12 if /[A-Z]/.test key
      return {buffer: @keys[@majorScaleNotes[index]]}
    else
      [index, velocity] = switch key
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
    console.log event
    {key, modifiers} = @keystrokeForKeyboardEvent(event)
    return unless key
    {buffer, velocity} = @bufferForEvent(key, modifiers)
    return unless buffer
    return if @sources[event.which]?.playbackState == 2

    gainNode = @context.createGain()
    gainNode.connect(@context.destination)
    gainNode.gain.value = velocity;

    source = @context.createBufferSource()
    @sources[event.which] = source
    source.buffer = buffer
    source.connect(gainNode);
    source.start(0)

  noteOff: (event) ->
    if source = @sources[event.which]
      @sources[event.which] = null
      source.gain.linearRampToValueAtTime(1, @context.currentTime)
      source.gain.linearRampToValueAtTime(0, @context.currentTime + 0.5)
      source.stop(@context.currentTime + 0.6)

  keystrokeForKeyboardEvent: (event) ->
    keyIdentifier = event.keyIdentifier
    if keyIdentifier.indexOf('U+') is 0
      hexCharCode = keyIdentifier[2..]
      charCode = parseInt(hexCharCode, 16)
      charCode = event.which if not @isAscii(charCode) and @isAscii(event.which)
      key = @keyFromCharCode(charCode)
    else
      key = keyIdentifier.toLowerCase()

    modifiers = []
    modifiers.push 'ctrl' if event.ctrlKey
    modifiers.push 'alt' if event.altKey
    if event.shiftKey
      # Don't push 'shift' when modifying symbolic characters like '{'
      modifiers.push 'shift' unless /^[^A-Za-z]$/.test(key)
      # Only upper case alphabetic characters like 'a'
      key = key.toUpperCase() if /^[a-z]$/.test(key)
    else
      key = key.toLowerCase() if /^[A-Z]$/.test(key)

    modifiers.push 'cmd' if event.metaKey

    key = null if key in ['meta', 'shift', 'control', 'alt']

    {key, modifiers}

  keyFromCharCode: (charCode) ->
    switch charCode
      when 8 then 'backspace'
      when 9 then 'tab'
      when 13 then 'enter'
      when 27 then 'escape'
      when 32 then 'space'
      when 127 then 'delete'
      else String.fromCharCode(charCode)

  isAscii: (charCode) ->
    0 <= charCode <= 127
