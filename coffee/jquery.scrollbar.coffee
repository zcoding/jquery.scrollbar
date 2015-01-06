# 外层容器的高度是明确不变的

defaults =
  classNames:
    content: "m-content"
    scrollbar: "m-scrollbar"
    controlbar: "u-bar"
  # 滚动条的位置 左/右
  position: "right"
  # 是否总是显示滚动条
  # 当内容框的高度小于等于外层容器的高度时，也就是并没有出现overflow的情况下，默认不显示滚动条（此时滚动条占100%）
  # always设置为true则总是显示滚动条
  always: no
  # 是否固定（即不会释放滚轮事件）
  fixed: no
  # 指定基准z-index
  baseZIndex: 10
  # 滚动到边缘时是否释放滚轮事件
  releaseMouse: yes

colors =
  gray: "#AAAAAA"
  lightGray: "#BBBBBB"
  lessGray: "#DDDDDD"
  darkGray: "#888888"

$.fn.scrollbar = (options) ->
  options = $.extend yes, {}, defaults, options

  # 控制常量
  Always = options.always

  $this = $(this)
  $doc = $(document)

  # 事件及其命名空间
  Namespace = "z_scroll"
  Events =
    mousedown: "mousedown.#{Namespace}"
    mouseup: "mouseup.#{Namespace}"
    mousewheel: "mousewheel.#{Namespace}"
    mousemove: "mousemove.#{Namespace}"
    click: "click.#{Namespace}"
    mouseenter: "mouseenter.#{Namespace}"
    mouseleave: "mouseleave.#{Namespace}"

  # 清除原有事件
  $this.off ".#{Namespace}"
  $doc.off ".#{Namespace}"

  $this.css {
    overflow: "hidden"
    position: "relative"
  }

  options.position = if /left|right/i.test options.position then options.position else 'right'

  $scrollbar = $this.children ".#{options.classNames.scrollbar}"
  $content = $this.children ".#{options.classNames.content}"
  $controlbar = $scrollbar.children()

  # 可计算CSS常量
  BorderRadius = 10
  ScrollbarWidth = 12
  ScrollbarBorder = 0

  # 如果不指定滚动条的高度，则以外层容器的高度作为滚动条的高度
  Height = options.height or $this.outerHeight()
  # 内容框的高度，一般不用指定
  ContentHeight = options.contentHeight or $content.outerHeight()
  # 高度比
  HeightRatio = Height / ContentHeight;

  # 必须保证滚动条在内容框的上方
  zIndex =
    content: $content.css "zIndex"
    container: $this.css "zIndex"
    scrollbar: $scrollbar.css "zIndex"

  if zIndex.content is "auto"
    zIndex.container = options.baseZIndex if zIndex.container is "auto"
    zIndex.content = zIndex.container + 1
    zIndex.scrollbar = zIndex.content + 1

  css =
    scrollbar:
      position: "absolute"
      top: 0
      borderRadius: BorderRadius
      cursor: "default"
      width: ScrollbarWidth
      height: Height
      background: colors.lessGray
      zIndex: zIndex.scrollbar
    controlbar:
      position: "absolute"
      top: 0
      left: 0
      borderRadius: BorderRadius
      cursor: "default"
      width: ScrollbarWidth
      height: "#{HeightRatio * 100}%"
      backgroundColor: colors.lightGray
    content:
      position: "absolute"
      top: 0
      left: 0
      zIndex: zIndex.content

  css.scrollbar[options.position] = 0
  css.scrollbar["display"] = "none" if ContentHeight < Height and not Always

  $scrollbar.css css.scrollbar
  $controlbar.css css.controlbar
  $content.css css.content

  $controlbar.addClass options.classNames.controlbar if not $controlbar.hasClass options.classNames.controlbar

  # 渲染滚动条
  render = (heightRatio) ->
    $controlbar.css {
      top: 0
      height: "#{heightRatio * 100}%"
    }
    $content.css {
      top: 0
    }
    if heightRatio is 1 and not Always
      $scrollbar.hide()
    else
      $scrollbar.show()

  DELTA = 50

  # 记录滚动位置
  Position =
    content: 0
    control: 0
    mouse: 0
    tmpContent: 0
    tmpControl: 0
  # 滚动范围
  Scope =
    content:
      min: Height - ContentHeight
      max: 0
    control:
      min: 0
      max: Height * (1 - HeightRatio)

  # 避免事件重叠
  Drag = false
  # 实现平滑滚动用到的计时器
  # Timer = null

  # 处理滚动到边缘时的滚轮事件
  mouse_count = 0
  MOUSE_MAX = 10
  release = no

  Handlers =
    mousewheel: (evt) ->
      move = Position.content + DELTA * evt.deltaY
      move = if move > Scope.content.max then Scope.content.max else move
      move = if move < Scope.content.min then Scope.content.min else move
      Position.content = move
      $content.css "top", Position.content
      scrollMove = -move * HeightRatio
      scrollMove = if scrollMove > Scope.control.max then Scope.control.max else scrollMove
      scrollMove = if scrollMove < Scope.control.min then Scope.control.min else scrollMove
      Position.control = scrollMove
      $controlbar.css "top", Position.control
      # 直接释放滚轮事件冒泡
      if options.fixed
        evt.stopPropagation()
        evt.preventDefault()
        return true
      # 滚动到边缘处理
      if (Position.control is Scope.control.min or Position.control is Scope.control.max) and options.releaseMouse
        mouse_count++
        if mouse_count is MOUSE_MAX
          mouse_count = 0
          release = yes
      else 
        release = no
      if not release
        evt.stopPropagation()
        evt.preventDefault()
      return true
    click: (evt) ->
      $target = $(evt.target)
      return false if $target.is ".#{options.classNames.controlbar}"

      offsets = $scrollbar.offset()
      mouseOffsetY = evt.pageY - offsets.top

      delta = if mouseOffsetY > Position.control + Height * HeightRatio then DELTA else -DELTA
      scrollMove = Position.control + delta
      scrollMove = if scrollMove > Scope.control.max then Scope.control.max else scrollMove
      scrollMove = if scrollMove < Scope.control.min then Scope.control.min else scrollMove
      Position.control = scrollMove
      $controlbar.animate {
        "top": scrollMove
      }, 100, "swing"
      move = Position.content - delta / HeightRatio
      move = if move > Scope.content.max then Scope.content.max else move
      move = if move < Scope.content.min then Scope.content.min else move
      Position.content = move
      $content.animate {
        "top": move
      }, 100, "swing"
      return true
    mousedown: (evt) ->
      Drag = true
      Position.mouse = evt.pageY
      Position.tmpControl = Position.control
      Position.tmpContent = Position.content
      $controlbar.css "backgroundColor", colors.darkGray
      $doc.on Events.mousemove, Handlers.mousemove
      return true
    mouseup: (evt) ->
      if Drag
        Drag = false
        Position.control = Position.tmpControl
        Position.content = Position.tmpContent
        Position.mouse = 0
        Position.tmpContent = 0
        Position.tmpControl = 0
        $target = $(evt.target)
        if $target.is ".#{options.classNames.controlbar}"
          $controlbar.css "backgroundColor", colors.gray
        else
          $controlbar.css "backgroundColor", colors.lightGray
        $doc.off Events.mousemove
      return true
    mousemove: (evt) ->
      deltaY = evt.pageY - Position.mouse
      scrollMove = Position.control + deltaY
      scrollMove = if scrollMove > Scope.control.max then Scope.control.max else scrollMove
      scrollMove = if scrollMove < Scope.control.min then Scope.control.min else scrollMove
      $controlbar.css "top", scrollMove
      Position.tmpControl = scrollMove
      move = Position.content - deltaY / HeightRatio
      move = if move > Scope.content.max then Scope.content.max else move
      move = if move < Scope.content.min then Scope.content.min else move
      $content.css "top", move
      Position.tmpContent = move
      evt.preventDefault()
      evt.stopPropagation()
      return true
    mouseenter: (evt) ->
      if not Drag
        $controlbar.css "backgroundColor", colors.gray
      return true
    mouseleave: (evt) ->
      if not Drag
        $controlbar.css "backgroundColor", colors.lightGray
      return true

  # 事件监听
  # 委托到$(this)上的事件：鼠标滚轮事件、鼠标按下事件、鼠标点击事件、hover事件（鼠标进入事件和鼠标移出事件）
  # 委托到$(document)上的事件：鼠标松开事件、鼠标移动事件
  $this.on Events.mousewheel, Handlers.mousewheel
  $this.on Events.mousedown, ".#{options.classNames.controlbar}", Handlers.mousedown
  $this.on Events.click, ".#{options.classNames.scrollbar}", Handlers.click
  $this.on Events.mouseenter, ".#{options.classNames.controlbar}", Handlers.mouseenter
  $this.on Events.mouseleave, ".#{options.classNames.controlbar}", Handlers.mouseleave

  $doc.on Events.mouseup, Handlers.mouseup

  return {
    # 重绘滚动条
    # @param {Number} contentHeight 内容框的高度
    # @param {Function} rendering 渲染中的回调
    repaint: (contentHeight, rendering = -> false) ->
      ContentHeight = contentHeight or $content.outerHeight()
      HeightRatio = Height / ContentHeight
      Scope.content.min = Height - ContentHeight
      Scope.control.max = Height * (1 - HeightRatio)
      if HeightRatio > 1
        Scope.content.min = 0
        Scope.control.max = 0
        HeightRatio = 1
      Position.content = 0
      Position.control = 0
      rendering.apply()
      render(HeightRatio)
    # 隐藏滚动条
    hide: ->
      $scrollbar.hide()

    # 显示滚动条
    show: ->
      $scrollbar.show()
  }