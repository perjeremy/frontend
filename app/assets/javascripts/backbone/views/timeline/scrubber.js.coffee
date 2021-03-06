DPLA.Views.Timeline ||= {}

class DPLA.Views.Timeline.Scrubber extends Backbone.View
  initialize: (options) ->
    this.timeline = options.timeline
    this.timeline.scrubber = this
    this.$el = $('.scrubber')
    this.timeline.on 'timeline:update_scrubber', this.updateScrubber, this
    this.timeline.on 'change:mode', this.changeMode, this

    this.isScrubberInitialized = false

  changeMode: (timeline) ->
    mode  = timeline.get('mode')
    year  = timeline.get('year')
    value = this.getSliderValue()
    if mode is 'decades'
      value -= 100000
    t = this

    this.$el.slider('destroy') if this.isScrubberInitialized

    this.$el.slider
      value: value
      min: 0
      max: timeline.get('endPoint') * 1000
      slide: (event, ui) ->
        mode  = t.timeline.get('mode')
        switch mode
          when 'decades'
            year = t.getSliderYear(t)
            t.timeline.set('year', year + 1000)
            timeline.trigger 'timeline:update_graph', ui.value
          when 'year'
            year = t.getSliderYear(t)
            if year > window.finalYear
              year = window.finalYear
      change: (event, ui) ->
        mode  = t.timeline.get('mode')
        switch mode
          when 'year'
            year = t.getSliderYear(t)
            oldYear = t.timeline.get('year')
            if year > window.finalYear
              year = window.finalYear
              t.timeline.set('year', year)
              t.updateScrubber(t.timeline)
            if year.toString() != oldYear
              t.timeline.router.navigate "//#{year}"

    unless $('.scrubber a span.arrow').length
      $('.scrubber a').append('<span class="arrow"></span><span class="icon-arrow-down" aria-hidden="true"></span>');

    this.isScrubberInitialized = true

    setTimeout ->
      timeline.trigger 'timeline:update_graph', t.$el.slider('value')
    , 100

  updateScrubber: (timeline) ->
    year = timeline.get('year')
    value = this.getSliderValue()
    this.$el.slider('value', value)

  getSliderValue: ->
    year = Math.round(this.timeline.get 'year')
    switch this.timeline.get 'mode'
      when 'decades'
        (year * 100000) / 1020 - 4000
      when 'year'
        (year - 1000) * 100000 / 1020

  getSliderYear: ->
    value = this.$el.slider('value')
    switch this.timeline.get 'mode'
      when 'decades'
        Math.round (value + 4000) * 1020 / 100000
      when 'year'
        1000 + Math.round (value) * 1020 / 100000

  nextYear: ->
    this.$el.slider "value", this.$el.slider("value") + 98.039257

  prevYear: ->
    this.$el.slider "value", this.$el.slider("value") - 98.039257