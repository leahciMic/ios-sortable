# CSS3 hardware accelerated sortable jQuery plugin
#
# Drag & drop reordering of elements using CSS transforms and transitions for
# buttery smooth animations on devices with limited CPU (mobile/tablets).
#
# Copyright (c) 2013 Michael Leaney <leahcimic@gmail.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms are permitted
# provided that the above copyright notice and this paragraph are
# duplicated in all such forms and that any documentation,
# advertising materials, and other materials related to such
# distribution and use acknowledge that the software was developed
# by the <organization>.  The name of the
# <organization> may not be used to endorse or promote products derived
# from this software without specific prior written permission.
# THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

class Sortable
  cssPrefix: (style) ->
    styles = window.getComputedStyle document.documentElement, ''
    pre = (Array.prototype.slice
      .call(styles)
      .join('')
      .match(/-(moz|webkit|ms)-/) || (styles.OLink == '' && ['', 'o'])
    )[1]
    dom = ('WebKit|Moz|MS|O').match(new RegExp('(' + pre + ')', 'i'))[1]
    "-#{pre}-#{style}"

  defaults:
    start: ->
    stop: ->
    update: ->
    $scrollEl: $(window)
    dragContainer: '> li'
    dragHandle: '.drag-handle'
    dragClass: 'flying-row'
    lockY: false
    lockX: false
    touchMoveEventName: 'touchmove'

  constructor: (config) ->
    _.defaults config, @defaults
    @throttledTouchMove = _.throttle @handleTouchMove, 25
    @scrollUp = _.throttle @scrollUp, 25
    @scrollDown = _.throttle @scrollDown, 25
    @config = config
    @cacheDropPositions()
    @resetProperties()

  destroy: ->
    @removeTransform @$cachedDroppables
    @$cachedDroppables.removeClass '-drag-container'
    @$cachedDroppables.find(@config.dragHandle).unbind 'touchstart', @handleTouchStart

  resetProperties: ->
    @$currentlyOver = false
    @lastOverIdx = false
    @$currentDraggable = false
    @$currentDraggableIdx = false

  buildTransformCSS: (transformObject) ->
    css = []
    for func, value of transformObject
      if value instanceof Array
        value = value.join ','
        css.push "#{func}(#{value})"
    css.join ''

  addTransform: ($el, func, value) ->
    if $el.length > 1
      $el.each (idx, element) =>
        @addTransform $(element), func, value
      return

    transform = $el.data('transform') || {}
    transform[func] = value
    $el.data 'transform', transform

    $el.css @cssPrefix('transform'), @buildTransformCSS transform

  removeTransform: ($el, func) ->
    if $el.length > 1
      $el.each (idx, element) =>
        @removeTransform $(element), func
      return

    transform = $el.data('transform') || {}

    if !func? || func == '*'
      transform = {}
    else
      delete transform[func]

    $el.data 'transform', transform

    $el.css @cssPrefix('transform'), @buildTransformCSS transform

  cacheDropPositions: ->
    @$cachedDroppables = @config.$sortContainer.find @config.dragContainer
    @$cachedDropPositions = []
    @$cachedDroppables.each (idx, element) =>
      $this = $(element)
      offset = $this.offset()
      @$cachedDropPositions.push
        x: offset.left - @config.$sortContainer.offset().left
        y: offset.top - @config.$sortContainer.offset().top
        w: $this.outerWidth false
        h: $this.outerHeight false
        $: $this

      unless $this.hasClass '-drag-container'
        $this.addClass '-drag-container'
        $this.find(@config.dragHandle).bind 'touchstart', @handleTouchStart

  refresh: ->
    @cacheDropPositions()

  handleTouchStart: (event) =>
    event.preventDefault && event.preventDefault()
    event.preventPropagation && event.preventPropagation()

    if @$currentDraggable
      return

    @config.start()
    touchEvent = event.originalEvent.targetTouches[0]

    @origPosition =
      x: touchEvent.pageX
      y: touchEvent.pageY

    @$currentDraggable = $(event.currentTarget).parents '.-drag-container'
    @$currentDraggable.addClass @config.dragClass

    @$cachedDroppables.not(@$currentDraggable).css(
      @cssPrefix('transition'), 'all 0.150s linear'
    )

    for dropPosition, dropPositionIdx in @$cachedDropPositions
      if dropPosition.$.get(0) == @$currentDraggable.get(0)
        @currentDraggableIdx = +dropPositionIdx

    $(document).bind 'touchend mouseup', @handleTouchEnd
    document.body.addEventListener @config.touchMoveEventName, @throttledTouchMove

  scroll: (amount) ->
    amount = Math.round amount

    scrollPosition = @config.$scrollEl.scrollTop()
    @config.$scrollEl.scrollTop(scrollPosition + amount)
    scrolledPixels = @config.$scrollEl.scrollTop() - scrollPosition

    @origPosition.y += -scrolledPixels

  scrollLoop: =>
    unless @isScrolling
      return
    @scroll @scrollForce * 20 # max speed is 800 pixels per second
    window.setTimeout @scrollLoop, 25

  handleTouchMove: (event) =>
    currentDroppableIdx = false

    event.preventDefault && event.preventDefault()
    event.preventPropagation && event.preventPropagation()

    if event instanceof CustomEvent
      event = event.detail

    unless @$currentDraggable
      return

    offset =
      x: if !@config.lockX then event.targetTouches[0].pageX - @origPosition.x else 0
      y: if !@config.lockY then event.targetTouches[0].pageY - @origPosition.y else 0

    percentOnPage = event.targetTouches[0].pageY / document.body.offsetHeight

    if percentOnPage < 0.1 || percentOnPage > 0.9
      wasScrolling = @isScrolling || false
      @isScrolling = true

      if percentOnPage < 0.1
        @scrollForce = (1 - percentOnPage / 0.1) * -1
      else
        @scrollForce = 1 - (1 - percentOnPage) / 0.1

      unless wasScrolling
        @scrollLoop()
    else
      @isScrolling = false

    @addTransform @$currentDraggable, 'translate', [offset.x + 'px', offset.y + 'px']

    foundMatch = false

    for dropPosition, dropPositionIdx in @$cachedDropPositions
      dropPositionIdx = +dropPositionIdx

      sortContainerOffset = @config.$sortContainer.offset()

      if dropPositionIdx != @currentDraggableIdx &&
         event.targetTouches[0].pageX - sortContainerOffset.left >= dropPosition.x &&
         event.targetTouches[0].pageX - sortContainerOffset.left <= dropPosition.x + dropPosition.w &&
         event.targetTouches[0].pageY - sortContainerOffset.top >= dropPosition.y &&
         event.targetTouches[0].pageY - sortContainerOffset.top <= dropPosition.y + dropPosition.h
        currentDroppableIdx = dropPositionIdx
        @$currentlyOver = dropPosition.$
        foundMatch = true
        break
      else if !foundMatch && @$currentlyOver
        @$currentlyOver = false

    if currentDroppableIdx && @lastOverIdx && currentDroppableIdx == @lastOverIdx
      return

    @lastOverIdx = currentDroppableIdx

    unless @$currentlyOver
      for dropPosition, dropPositionIdx in @$cachedDropPositions
        if dropPosition.moveBy?
          delete dropPosition.moveBy
          @removeTransform dropPosition.$, 'translate'
      return

    for dropPosition, dropPositionIdx in @$cachedDropPositions
      dropPositionIdx = +dropPositionIdx
      isShiftingLeft = @currentDraggableIdx < currentDroppableIdx
      @shouldInsertBefore = !isShiftingLeft

      if (
           isShiftingLeft &&
           dropPositionIdx > @currentDraggableIdx &&
           dropPositionIdx <= currentDroppableIdx
         ) || (
           !isShiftingLeft &&
           dropPositionIdx < @currentDraggableIdx &&
           dropPositionIdx >= currentDroppableIdx
         )
            if isShiftingLeft
              swapWith = @$cachedDropPositions[dropPositionIdx - 1]
            else
              swapWith = @$cachedDropPositions[dropPositionIdx + 1]

            moveBy =
              x: dropPosition.x - swapWith.x
              y: dropPosition.y - swapWith.y

            @addTransform(
              dropPosition.$,
              'translate',
              [(moveBy.x*-1) + 'px', (moveBy.y*-1) + 'px']
            )

            dropPosition.moveBy = moveBy

          else if dropPositionIdx != @currentDraggableIdx && dropPosition.moveBy?
            delete dropPosition.moveBy
            @removeTransform dropPosition.$, 'translate'

  handleTouchEnd: (event) =>
    event.preventDefault && event.preventDefault()
    event.preventPropagation && event.preventPropagation()

    $(document).unbind 'touchend mouseup', @handleTouchEnd

    document.body.removeEventListener 'faketouchmove', @throttledTouchMove

    if @$currentlyOver && @$currentDraggable.get(0) != @$currentlyOver.get(0)
      if @shouldInsertBefore
        @$currentDraggable.insertBefore @$currentlyOver
      else
        @$currentDraggable.insertAfter @$currentlyOver
      @config.update()

    @$cachedDroppables.css @cssPrefix('transition'), ''
    @removeTransform @$cachedDroppables
    @$currentDraggable.removeClass @config.dragClass

    @resetProperties()
    @cacheDropPositions()

    @config.stop()

$.fn.sortable = (config) ->
  config.$sortContainer = $(@)
  new Sortable config