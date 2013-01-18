# cscott's very simple splitter widget

Splitter =
  vsize:
    get: () -> $('.bb-bottom-content').height()
    set: (size) ->
      if not size?
        # resize to let top content be fully visible
        SPLITTER_WIDGET_HEIGHT = 6 # pixels
        topHeight = $('.bb-top-left-content')[0]?.scrollHeight
        if topHeight? and topHeight > 0
          topHeight += SPLITTER_WIDGET_HEIGHT
          size = $('.bb-splitter').innerHeight() - topHeight
        else
          size = 300
      $('.bb-splitter').css 'padding-bottom', +size
      $('.bb-bottom-content').css 'height', +size
      +size
  hsize:
    get: () -> $('.bb-top-right-content').width()
    set: (size) ->
      SPLITTER_WIDGET_WIDTH = 6 # pixels
      if not size?
        # 200px wide chat
        size = 200
      $('.bb-top-content').css 'padding-right', +size + SPLITTER_WIDGET_WIDTH
      $('.bb-top-content > .bb-splitter-handle').css 'right', +size
      $('.bb-top-right-content').css 'width', +size
      +size
  handleEvent: (event, template) ->
    console.log $(event.currentTarget).closest('.bb-top-content')
    if $(event.currentTarget).closest('.bb-top-content').length
      this.handleHEvent event, template
    else
      this.handleVEvent event, template
  handleVEvent: (event, template) ->
    event.preventDefault() # don't highlight text, etc.
    pane = $(event.currentTarget).closest('.bb-splitter')
    initialPos = event.pageY
    initialSize = Splitter.vsize.get()
    mouseMove = (event) ->
      newSize = initialSize - (event.pageY - initialPos)
      Splitter.vsize.set newSize
    mouseUp = (event) ->
      pane.removeClass('active')
      $(document).unbind('mousemove', mouseMove).unbind('mouseup', mouseUp)
    pane.addClass('active')
    $(document).bind('mousemove', mouseMove).bind('mouseup', mouseUp)
  handleHEvent: (event, template) ->
    event.preventDefault() # don't highlight text, etc.
    pane = $(event.currentTarget).closest('.bb-top-content')
    initialPos = event.pageX
    initialSize = Splitter.hsize.get()
    mouseMove = (event) ->
      newSize = initialSize - (event.pageX - initialPos)
      Splitter.hsize.set newSize
    mouseUp = (event) ->
      pane.removeClass('active')
      $(document).unbind('mousemove', mouseMove).unbind('mouseup', mouseUp)
    pane.addClass('active')
    $(document).bind('mousemove', mouseMove).bind('mouseup', mouseUp)
