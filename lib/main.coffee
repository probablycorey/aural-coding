AuralCoding = require './aural-coding'

module.exports =
  auralCoding: null

  activate: ->
    @auralCoding = new AuralCoding()

  deactivate: ->
    @auralCoding?.unsubscribe()
    @auralCoding = null
