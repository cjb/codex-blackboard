# cscott's very simple splitter widget

Splitter =
  size:
    get: () -> $('.bb-bottom-content').height()
    set: (size) ->
      if not size?
        # resize to let top content be fully visible
        SPLITTER_WIDGET_HEIGHT = 6 # pixels
        topHeight = $('.bb-top-content')[0]?.scrollHeight
        if topHeight? and topHeight > 0
          topHeight += SPLITTER_WIDGET_HEIGHT
          size = $('.bb-splitter').innerHeight() - topHeight
        else
          size = 300
      $('.bb-splitter').css 'padding-bottom', +size
      $('.bb-bottom-content').css 'height', +size
      +size
  handleEvent: (event, template) ->
    event.preventDefault() # don't highlight text, etc.
    pane = $(event.currentTarget).closest('.bb-splitter')
    initialPos = event.pageY
    initialSize = Splitter.size.get()
    mouseMove = (event) ->
      newSize = initialSize - (event.pageY - initialPos)
      Splitter.size.set newSize
    mouseUp = (event) ->
      pane.removeClass('active')
      $(document).unbind('mousemove', mouseMove).unbind('mouseup', mouseUp)
    pane.addClass('active')
    $(document).bind('mousemove', mouseMove).bind('mouseup', mouseUp)
        
