class DPLA.MapRouter extends Backbone.Router

  routes:
    ""      : "index"

  index: ->
    mapModel = new DPLA.MapModel()
    @view = new DPLA.MapView({ model: mapModel })
