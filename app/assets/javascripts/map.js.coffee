$(document).ready ->
  if $('.map-controller').length
    wrapper = new MapWrapper('map')
    map = wrapper.map
    $('#toggle').on 'click', ->
      setTimeout ->
        map.invalidateSize()
      , 500

  # map variable for debugging purposes
  window.map     = map
  window.wrapper = wrapper

MapWrapper = L.Class.extend
  _layers:       {}
  _drawedItems:  {}
  _requestsPool: []
  _openPopups:   []

  initialize: (domId)->
    this.map = L.map 'map',
      center: new L.LatLng(38, -93)
      zoom: 4
      layers: this.getBaseLayer()
    t = this
    this.map.on
      dragend: ->
        t.onDragend()
      zoomstart: ->
        t.onZoomstart()
      zoomend: ->
        t.onZoomend()
    this.updateMapMarkers()
    this.navigateToHashParams()

  onDragend: ->
    this.updateMapMarkers()

  onZoomstart: ->
    this.closeAllOpenPopups()

  onZoomend: ->
    this.updateMapMarkers()

  navigateToHashParams: ->
    pos =
      lat: $.address.parameter 'lat'
      lng: $.address.parameter 'lng'
      zoom: $.address.parameter 'zoom'
    if pos.lat && pos.lng
      this.map.panTo(new L.LatLng(pos.lat, pos.lng))
    if pos.zoom
      this.map.setZoom(pos.zoom)


  updateMapMarkers: ->
    stateLayer  = this.getStateLayer()
    pointsLayer = this.getRegularLayer()

    this.map.addLayer stateLayer
    switch
      when this.map.getZoom() in [4..6]
        this.map.removeLayer pointsLayer
      else
        this.requestRegularMarkers(this.getMapPosition())
        this.map.addLayer    pointsLayer

  roundMapClusterCount: (count)->
    switch
      when count > 999
        "#{ Math.round(count / 1000) }K"
      when count > 999999
        "#{ Math.round(count / 1000 / 1000) }M"
      else
        count

  getMapPosition: ->
    center      = this.map.getCenter()
    northWest: this.map.getBounds().getNorthWest()
    southEast: this.map.getBounds().getSouthEast()
    lat: center.lat
    lng: center.lng
    zoom: this.map.getZoom()

  turnProgress: (turn)->
    if turn
      $('#loading').show()
    else
      $('#loading').hide()

  closeAllOpenPopups: ->
    $.each this._openPopups, (i,popup)->
      popup._close()

  getBaseLayer: ->
    unless this._layers.base
      tileUrl = 'http://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'
      copyright = 'Map data &copy; <a href="http://openstreetmap.org">OpenStreetMap</a> contributors, <a href="http://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>'
      this._layers.base = L.tileLayer tileUrl, attribution: copyright, minZoom: 4, maxZoom: 18
    this._layers.base

  getStateLayer: ->
    unless this._layers.state
      statesMarkers = []
      if window.states instanceof Array
        t = this
        $.each window.states, (i,state)->
          roundedTotalCount = t.roundMapClusterCount state.count
          marker = new L.marker [state.lat, state.lng],
            icon: new L.DivIcon
              html: '<div class="mapCluster"><span class="resultnumber">' + roundedTotalCount + '</span></div>'
              className: 'dot more-results'
              iconSize: new L.Point 20, 20
          marker.data = state
          marker.on 'click', (e)->
            state = e.target.data
            t.openStatePopup state, e.target.getLatLng()
          statesMarkers.push marker
      markerCluster = new L.MarkerClusterGroup
        iconCreateFunction: (cluster) ->
          totalCount = 0
          $.each cluster.getAllChildMarkers(), (i,point)->
            totalCount += point.data.count if point.data.count
          roundedTotalCount = t.roundMapClusterCount totalCount
          new L.DivIcon({html: '<div class="mapCluster"><span class="resultnumber">' + roundedTotalCount + '</span></div>', className: 'dot more-results', iconSize: new L.Point(20, 20)})
        spiderfyOnMaxZoom: false
        showCoverageOnHover: false
        zoomToBoundsOnClick: false
      markerCluster.addLayers statesMarkers
      markerCluster.on 'clusterclick', (cluster)->
        relevantChilds = cluster.layer.getAllChildMarkers().sort (a,b)->
          b.data.count - a.data.count
        t.openStatePopup relevantChilds.shift().data, cluster.layer.getLatLng()


      this._layers.state = markerCluster
    this._layers.state

  openStatePopup: (state, latlng)->
    while this._requestsPool.length > 0
      this._requestsPool.shift().abort()

    t = this
    this._requestsPool.push $.ajax
      url: window.api_search_path
      data:
        'sourceResource.spatial.state': state.name
        'page_size': 50
      dataType: 'jsonp'
      cache: true
      beforeSend: ->
        t.turnProgress true
      success: (data)->
        if $.isPlainObject(data) and $.isArray(data.docs)
          points = $.map data.docs, (doc)->
            t.doc2point doc
          state_search_href = "/search?#{ window.app_search_path }&state[]=#{ state.name }"
          link_to_state_search = """
            <a href="#{ state_search_href }">#{ state.name }</a>
          """
          popup = t.generatePopup(points, link_to_state_search).setLatLng(latlng)
          t._openPopups.push popup.openOn(t.map, {x: 20, y: 10})
      complete: (jqXHR, textStatus)->
        t.turnProgress false

  getRegularLayer: ->
    t = this
    unless this._layers.points
      markerCluster = new L.MarkerClusterGroup
        iconCreateFunction: (cluster) ->
          totalCount = cluster.getChildCount()
          roundedTotalCount = t.roundMapClusterCount totalCount
          new L.DivIcon({html: '<div class="mapCluster"><span class="resultnumber">' + roundedTotalCount + '</span></div>', className: 'dot more-results', iconSize: new L.Point(20, 20)})
        spiderfyOnMaxZoom: false
        showCoverageOnHover: false
        zoomToBoundsOnClick: false
      markerCluster.on 'clusterclick', (cluster)->
        points = cluster.layer.getAllChildMarkers()
        location = t.getClusterLocation(points)
        location_search_href = "/search?#{ window.app_search_path }&place[]=#{ location }"
        link_to_location_search = """
          <a href="#{ location_search_href }">#{ location }</a>
        """
        popup = t.generatePopup(points.slice(0,50), link_to_location_search)
          .setLatLng(cluster.layer.getLatLng())
        t._openPopups.push popup.openOn(t.map, {x: 20, y: 10})
      this._layers.points = markerCluster
    this._layers.points

  requestRegularMarkers: (position)->
    while this._requestsPool.length > 0
      this._requestsPool.shift().abort()

    t = this
    this._requestsPool.push $.ajax
      url: window.api_search_path
      data:
        'sourceResource.spatial.coordinates': "#{position.northWest.lat},#{position.northWest.lng}:#{position.southEast.lat},#{position.southEast.lng}"
        'page_size': 500
      dataType: 'jsonp'
      cache: true
      beforeSend: ->
        t.turnProgress true
      success: (data)->
        if $.isPlainObject(data) and $.isArray(data.docs)
          t.drawRegularItems data.docs
      complete: (jqXHR, textStatus)->
        t.turnProgress false

  drawRegularItems: (docs)->
    t = this
    toDraw = []
    $.each docs, (i, doc)->
      unless t._drawedItems[doc.id]
        t._drawedItems[doc.id] = true
        point = t.doc2point doc
        if point
          myIcon = L.divIcon
            className: 'dot'
            iconSize: new L.Point 0, 0
          marker = new L.marker([point.lat, point.lng], {icon: myIcon})
          marker.data = point
          marker.on 'click', (e)->
            popup = t.generatePopup(e.target).setLatLng(e.target.getLatLng())
            t._openPopups.push popup.openOn(t.map, {x: 20, y: 0})
          toDraw.push marker

    t.getRegularLayer().addLayers toDraw

  getClusterLocation: (points)->
    locations = {}
    $.each points, (i, point)->
      $.each point.data.location, (i,loc)->
        if locations[loc]
          locations[loc]++
        else
          locations[loc] = 1
    locationName = ''
    locationScore = 0
    $.each locations, (name, score)->
      if locationScore < score
        locationName = name
        locationScore = score
    locationName

  doc2point: (doc)->
    coordinates = []
    if $.isArray(doc['sourceResource.spatial.coordinates'])
      coordinates = try
        doc['sourceResource.spatial.coordinates'][0].split ','
      catch error
        []
    else if doc['sourceResource.spatial.coordinates']
      coordinates = doc['sourceResource.spatial.coordinates'].split ','
    location = doc['sourceResource.spatial.name']
    location = [location] unless location instanceof Array
    point =
      id: doc.id
      title: doc['sourceResource.title'] || doc['id']
      thumbnail: doc['object']
      type: doc['sourceResource.type'] || ''
      creator: doc['sourceResource.creator'] || ''
      location: location
      url: doc['isShownAt']
      lat: coordinates.shift()
      lng: coordinates.shift()


  generatePopup: (points, title) ->
    t = this
    points = [points] unless points instanceof Array

    base_uri = window.location.href
    if window.location.href.indexOf('#') > 0
      base_uri = base_uri.substr(0, window.location.href.indexOf('#'))
    pos = t.getMapPosition()
    back_uri = "#{ base_uri }#/?lat=#{ pos.lat }&lng=#{ pos.lng }&zoom=#{ pos.zoom }"

    html = ''
    $.each points, (i,point) ->
      point = if $.isPlainObject(point) then point else point.data
      item_href = "/item/#{ point.id }?back_uri=#{ encodeURIComponent(back_uri) }"
      item_title = point.title
      if $.isArray(item_title)
        item_title = item_title[0]
      content =
        """
          <h6> #{ point.type }</h6>
          <h4><a href="#{ item_href }">#{ item_title }</a></h4>
          <p><span> #{ point.creator }</span></p>
          <a class="ViewObject" href="#{ point.url }" target="_blank">View Object <span class="icon-view-object" aria-hidden="true"></span></a>
        """
      if point.thumbnail
        html +=
          """
            <div class="box-row">
              <div class="box-right"><img onerror="image_loading_error(this);" src="#{ point.thumbnail }" /></div>
              <div class="box-left">#{ content }</div>
            </div>
          """
      else
        html += "<div class=\"box-row\">#{ content }</div>"

    html = '<div class="box-rows">' + html + '</div>' if points.length > 1
    html = "<h5>#{ title }</h5>" + html if title
    popup = new DPLAPopup offset: new L.Point(-10,-30)
    popup.setContent html


DPLAPopup = L.Popup.extend
  _initLayout: ->
    this._container = mapBox = L.DomUtil.create 'div', 'mapBox'
    L.DomEvent.disableClickPropagation mapBox
    closeButton = L.DomUtil.create 'a', 'closePopUp', mapBox
    closeButton.href = '#close'
    closeButton.innerHTML = '&#215;'
    L.DomEvent.on closeButton, 'click', this._onCloseButtonClick, this
    this._contentNode = L.DomUtil.create 'div', 'boxInner', mapBox
    L.DomEvent.on(this._contentNode, 'mousewheel', L.DomEvent.stopPropagation)
    this._tip = L.DomUtil.create('div', 'mapArrow', mapBox)
  _updateLayout: ->
    container = this._contentNode
    this._containerWidth = container.offsetWidth
    this._container.style.bottom = 50 + 'px'
    this._container.style.left = 50 + 'px'
  openOn: (m, adjust = {x: 10, y: 20})->
    L.Popup.prototype.openOn.call(this, m)
    this._container.style.left = (this._containerLeft + adjust.x) + 'px'
    this._container.style.bottom = (this._containerBottom + adjust.y) + 'px'
    return this;