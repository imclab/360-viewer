#{{{1 Roadmap
#{{{2 Done
# 
#{{{3 Milestone 2 - December 2013 / January 2014
#
# - open source - available on github
# - use solapp for automatic minification and easier development
#
#{{{3 Milestone 1 - October/November 2013
#
# - avoid moving zoom-lens beyond image / constraint on edge
# - allow interaction during rotate
# - gif spinner indicator
# - logo on top with fade-out 
# - zoom button
# - fullscreen button
# - fullscreen(on both desktop and mobile)
# - dynamic load hi-res images (on fullscreen after .5s same image + zoom use scaled lo-res when starting) + recache lo-res
# 
#{{{3 Milestone 0 - September 2013
# 
# - Version up and running
# - Browser-support: IE8+, iOS 5+ Android 4+
# - Rotate on drag
# - Handle touch and mouse
# - Zoom-lens effect(on desktop+mobile)
# - Zoom on click (on desktop) and on hold (on mobile)
# - Cursor icon
# - Image caching / preloader
# - Animate on load
# 
#{{{2 TODO
#{{{3 Initial version
# 
# - collect statistics
# - fix android full-screen issues
# - connect with API (implemented with local version, waiting for proper jsonp on backend)
# - IE - test
# 
#{{{3 Future
# 
# - multitouch - see if we can enable zoom/scroll by no-preventDefault when multifinger (no, difficult, look into this later)
# - customer logo(postponed due to no customer logo links in sample data from the api)
# - labels/markers/interaction points (postponed due to no markers/interaction points in the sample data from the api)
# - fullscreen issues on android when user-scaleable
# - maybe close fullscreen on click outside image
# - test/make sure it works also wit small data sets of 1. picture
# - icons / documentation - zoom-lense(desktop), fullscreen, close(fullscreen)
# - animate during load, instead of animate on load
# - thumbnails when few pictures (maybe instead of drag)
# - smoother animate on load
# 
# 
#{{{1 Technical approach
#
# When targeting mobile devices,
# and possibly several 360º views on a page,
# memory is more likely to be bottleneck than CPU.
# 
# We therefore just preload the compressed images
# into the browsers component cache, 
# and decompress them at render time.
# 
# The actual rendering is then just replacing
# the `src` of an image tag, - also making it work
# in non-HTML5 browsers, such as IE8, 
# which we also need to support.
#
#{{{1 Development code
#
# The following code is used during development.
# It will automatically be removed when it is compiled and minified.
#
# The globalDefines sets `isTesting`, `isDevServer` and `isNodeJs` predicates which can be used for conditional code, ie. code present in the file used for test and development that will be removed from the production build.
require("solapp").globalDefines global if typeof isNodeJs != "boolean"

#{{{2 Meta information about the application 
# This is primarily used for the README.md and to make sure necessary css are included when the devserver is running, and also that the minified version `webjs` is build.
if isNodeJs
  exports.about =
    title: "360º Viewer"
    description: "Widget for showing OneTwo360 images/animations"
    owner: "onetwo360"
    name: "360"
    html5:
      userScaleable: true
      css: [
        "http://onetwo360.com/themes/onetwo360/site/360logofont.css"
        "//netdna.bootstrapcdn.com/font-awesome/4.0.1/css/font-awesome.css"
      ]
    webjs: true
    package:
      dependencies:
        solapp: "*"

#{{{1 Utilities
if !isNodeJs
  # General Utility functions {{{2
  sleep = (time, fn) -> setTimeout fn, time*1000
  floatPart = (n) -> n - Math.floor(n)
  nextTick = (fn) -> setTimeout fn, 0
  identityFn = (e) -> e
  nop = -> undefined
  runOnce = (fn) -> (args...) -> if fn then fn args...; fn = undefined else undefined
  extend = (target, sources...) -> #{{{3
    for source in sources
      for key, val of source
        target[key] = val
    target
  asyncEach = (arr, fn, done) -> #{{{3
    done = runOnce done
    remaining = arr.length
    next = (err) ->
      done err if err
      done() if not --remaining
    fn elem, next for elem in arr
    undefined
  
  #{{{2 Browser abstractions and utilities
  #
  # Added here, because of requirement of no dependencies, - would otherwise use jquery or similar
  #
  Date.now ?= -> (+ new Date())
  body = document.getElementsByTagName("body")[0] # TODO: make sure this runs after onload
  onComplete = (fn) -> do f = -> if document.readyState == "interactive" or document.readyState == "complete" then fn() else setTimeout f, 10
  setStyle = (elem, obj) -> #{{{3
    for key, val of obj
      try
        elem.style[key] = val
      catch e
        e
    elem
  elemAddEventListener = (elem, type, fn) -> #{{{3
    if elem.addEventListener
      elem.addEventListener type, fn, false
    else
      elem.attachEvent "on"+type, fn
  get = (url, callback) -> #{{{3
    req = new XMLHttpRequest() #TODO IE-compat
    req.onload = ->
      callback null, req.responseText
    req.open "get", url, true
    req.send()
  
  #{{{2 Web utilities
  cacheImgs = (urls, callback) -> #{{{3
    loadImg = (url, done) ->
      img = new Image()
      img.src = url
      img.onload = -> done()
    asyncEach urls, loadImg, callback
  #{{{3 maximize
  #
  # implementation disable at the moment, as we have another approach
  if false
    maximize = (elem) ->
      oldbody = document.createElement "div"
      oldbody.style.display = "none"
      parent = elem.parentElement
      nextSibling = elem.nextSibling
    
      body.appendChild oldbody
      for node in (node for node in body.childNodes)
        oldbody.appendChild node if node != oldbody
      body.appendChild elem
    
      ->
        for node in (node for node in oldbody.childNodes)
          body.appendChild node
        oldbody.remove()
        if nextSibling
          elem.insertBefore nextSibling
        else
          parent.appendChild elem
    
  # Touch handler {{{2
  touchHandler = undefined
  setTouch = undefined
  do ->
    touch = undefined
    setTouch = (t) -> touch = t
  
    tapLength = 500 # maximum time for a click, - turns into a hold after that
    tapDist2 = 10*10 # maximum dragged (squared) distance for a click
  
    updateTouch = (touch, e) -> #{{{3
      x = e.clientX
      y = e.clientY
      touch.event = e
      touch.ddx = x - touch.x || 0
      touch.ddy = y - touch.y || 0
      touch.dx = x - touch.x0
      touch.dy = y - touch.y0
      touch.maxDist2 = touch.dx * touch.dx + touch.dy * touch.dy
      touch.time = Date.now() - touch.startTime
      touch.x = x
      touch.y = y
  
    startTouch = (e, handler, touchObj) -> #{{{3
      touch = touchObj
      touch.handler = handler
      touch.x0 = e.clientX
      touch.y0 = e.clientY
      touch.x = e.clientX
      touch.y = e.clientY
      touch.startTime = Date.now()
      updateTouch touch, e
      touch.ctx = handler.start(touch)
      holdHandler = ->
        if touch && !touch.holding && touch.maxDist2 < tapDist2
          touch.holding = true
          touch.handler.hold touch
      setTimeout holdHandler, tapLength
  
    moveTouch = (e) -> #{{{3
      updateTouch touch, e
      touch.ctx = touch.handler.move touch || touch.ctx
  
    stopTouch = (e) -> #{{{3
      touch.handler.end touch
      touch.handler.click touch if touch.maxDist2 < tapDist2 && touch.time < tapLength
      touch = undefined
  
    condCall = (fn) -> (e) -> #{{{3
      return undefined if !touch
      e.preventDefault?()
      fn(e.touches?[0] || e)
  
    documentTouch = runOnce -> #{{{3
      elemAddEventListener document, "mousemove", condCall moveTouch
      elemAddEventListener document, "touchmove", condCall moveTouch
      elemAddEventListener document, "mouseup", condCall stopTouch
      elemAddEventListener document, "touchend", condCall stopTouch
  
    touchHandler = (handler) -> #{{{3
      elemAddEventListener handler.elem, "mousedown", (e) ->
        e.preventDefault?()
        startTouch e, handler, {isMouse: true}
      elemAddEventListener handler.elem, "touchstart", (e) ->
        e.preventDefault?()
        startTouch e.touches[0], handler, {}
  
      documentTouch()
      handler.start ||= nop
      handler.move ||= nop
      handler.end ||= nop
      handler.drag ||= nop
      handler.click ||= nop
      handler.hold ||= nop
  
      handler
  
  # 360º specific {{{1
  do ->
    callbackNo = 0
    zoomWidth = undefined
    zoomHeight = undefined
    zoomSize = 200
    eventHandler = undefined
    untouched = true
    default360Config = #{{{2
      autorotate: true
      imageURLs: undefined
  
    # Create zoom lens element{{{3
    onComplete ->
      body = document.getElementsByTagName("body")[0]
      zoomLens = document.createElement "div"
      setStyle zoomLens,
        position: "absolute"
        overflow: "hidden"
        width: zoomSize + "px"
        height: zoomSize + "px"
        border: "0px solid black"
        cursor: "default"
        backgroundColor: "rgba(100,100,100,0.8)"
        borderRadius: (zoomSize/2) + "px"
        #borderBottomRightRadius: (zoomSize/5) + "px"
        boxShadow: "0px 0px 40px 0px rgba(255,255,255,.7) inset, 4px 4px 9px 0px rgba(0,0,0,0.5)"
        display: "none"
      zoomLens.id = "zoomLens360"
      body.appendChild zoomLens
  
    # Add 360 elem to page {{{3
    window.onetwo360 = (cfg) ->
  
      currentAngle = 0
      width = undefined
      height = undefined
      doZoom = undefined
      endZoom = undefined
      logoElem = undefined
  
      # Create img element for writing animation to {{{3
      elem = document.getElementById cfg.elem_id
      container = document.createElement "div"
      setStyle container,
        display: "inline-block"
        position: "relative"
      img = new Image()
      eventHandler = touchHandler {elem: elem}
      elem.appendChild container
      container.appendChild img
      img.src = "spinner.gif"
      setStyle img,
        position: "absolute"
        top: "49%"
        left: "49%"
  
  
      overlay = ->
        setStyle img,
          top: "0px"
          left: "0px"
        spinnerElem?.remove()
        w = cfg.request_width
        h = cfg.request_height
        logoElem = document.createElement "i"
        logoElem.className = "icon-OneTwo360Logo"
        container.appendChild logoElem
        setStyle logoElem,
          position: "absolute"
          top: h*.35 + "px"
          left: w*.25  + "px"
          opacity: "0.7"
          textShadow: "0px 0px 5px white"
          fontSize: h*.2 + "px"
          color: "#333"
          transition: "opacity 1s"
        logoElem.onmouseover = ->
          logoElem.style.opacity = "0"
  
        buttonStyle = (el) ->
          setStyle el,
            position: "absolute"
            color: "#333"
            opacity: "0.7"
            textShadow: "0px 0px 5px white"
            backgroundColor: "rgba(255,255,255,0)"
            fontSize: h * .08 + "px"
            padding: h*.02 +"px"
          el
  
        fullScreenElem = document.createElement "i"
        fullScreenElem.className = "fa fa-fullscreen"
        fullScreenElem.ontouchstart = fullScreenElem.onmousedown = toggleFullScreen
        container.appendChild fullScreenElem
        setStyle (buttonStyle fullScreenElem),
          top: h *.85 + "px"
          left : w - h *.15 + "px"
  
        zoomElem = document.createElement "i"
        zoomElem.className = "fa fa-search"
        container.appendChild zoomElem
        setStyle (buttonStyle zoomElem),
          top: h *.85 + "px"
          left : 0 + "px"
  
      nextTick -> get360Config()
  
  
      # Get config+imagelist from server {{{3
      get360Config = ->
        callbackName = "callback" + ++callbackNo
        window[callbackName] = (data) ->
          console.log data
          serverConfig =
            imageURLs: (data.baseUrl + file.normal for file in data.files)
            zoomURLs: (data.baseUrl + file.zoom for file in data.files)
            request_width: data.width
            request_height: data.width
          zoomWidth = data.zoomWidth
          zoomHeight = data.zoomHeight
          cfg = extend {}, default360Config, serverConfig, cfg
          init360Elem()
          scriptTag.remove()
          setStyle elem,
            display: "inline-block"
            width: data.width + "px"
            height: data.height + "px"
            overflow: "hidden"
          setStyle container,
            width: data.width + "px"
            height: data.height + "px"
          delete window[callbackName]
        scriptTag = document.createElement "script"
        scriptTag.src = "http://embed.onetwo360.com/" + cfg.product_id + "?callback=" + callbackName
        document.getElementsByTagName("head")[0].appendChild scriptTag
    
      # Initialise the 360º object {{{3
      init360Elem = ->
        cache360Images ->
          setStyle img,
            width: cfg.request_width + "px"
            height: cfg.request_height + "px"
            cursor: "url(res/cursor_rotate.cur),move"
          width = cfg.request_width
          height = cfg.request_height
  
          overlay()
          init360Controls()
          if cfg.autorotate
            autorotate nop
    
      # Load images into cache, and possibly autorotate {{{3
      cache360Images = (done) -> cacheImgs cfg.imageURLs, done
  
      # Autorotate {{{3
      autorotate = (done) ->
        untouched = true
        currentAngle = 0
        showNext = ->
          if untouched and currentAngle < Math.PI * 2
            currentAngle = currentAngle + 0.2
            updateImage()
            #img.onload = -> setTimeout showNext, 10 # doesnt work in ie8
            setTimeout showNext, 60
          else
            done()
        showNext()
    
      # Update the current viewed image {{{3
      updateImage = ->
        img.src = cfg.imageURLs[floatPart(currentAngle/Math.PI/2) * cfg.imageURLs.length | 0]
        imgsrc = img.src
        if fullScreenOriginalState
          sleep .5, ->
            largeImage = new Image
            largeImage.onload = ->
              console.log "here", imgsrc, img.src
              if imgsrc == img.src
                img.src = largeImage.src
              cache360Images nop
            largeImage.src = cfg.zoomURLs[floatPart(currentAngle/Math.PI/2) * cfg.imageURLs.length | 0]
  
      # init controls {{{3
      init360Controls = ->
        eventHandler.move = (t) ->
          if t.holding || t.zoom360
            nextTick -> doZoom t
          else
            currentAngle -= 2 * Math.PI * t.ddx / width
            updateImage()
        eventHandler.hold = (t) -> nextTick -> doZoom t
        eventHandler.start = (t) ->
          setStyle logoElem,
            opacity: "0"
          untouched = false
        eventHandler.end = (t) -> nextTick -> endZoom t
        eventHandler.click = (t) -> if t.isMouse
          t.zoom360 = true
          nextTick -> setTouch t
  
      # Zoom handling {{{3
      zoomSrc = undefined
      doZoom = (t) ->
        zoomLens = document.getElementById "zoomLens360"
        if zoomSrc == undefined
          normalSrc = cfg.imageURLs[floatPart(currentAngle/Math.PI/2) * cfg.zoomURLs.length | 0]
          largeSrc = cfg.zoomURLs[floatPart(currentAngle/Math.PI/2) * cfg.zoomURLs.length | 0]
          zoomSrc = normalSrc
          loadZoom = new Image
          loadZoom.onload = -> if zoomSrc == normalSrc
            zoomSrc = largeSrc
            doZoom t
          loadZoom.src = largeSrc
        imgPos = img.getBoundingClientRect()
        minY = imgPos.top
        maxY = imgPos.bottom
        minX = imgPos.left
        maxX = imgPos.right
        imgWidth = maxX - minX
        imgHeight = maxY - minY
        touchX = .5
        touchY = if t.isMouse then .5 else 1.1
        y = Math.min(maxY, Math.max(minY, t.y))
        x = Math.min(maxX, Math.max(minX, t.x))
        zoomLeftPos = x + body.scrollLeft - zoomSize * touchX
        zoomTopPos = y + body.scrollTop - zoomSize * touchY
        bgLeft = zoomSize*touchX-((x-imgPos.left) * zoomWidth / (imgWidth))
        bgTop = zoomSize*touchY-((y-imgPos.top) * zoomHeight / (imgHeight))
        setStyle zoomLens,
          display: "block"
          position: "absolute"
          left: zoomLeftPos + "px"
          top: zoomTopPos + "px"
          backgroundImage: "url(#{zoomSrc})"
          backgroundSize: "#{zoomWidth}px #{zoomHeight}px"
          backgroundPosition: "#{bgLeft}px #{bgTop}px"
          backgroundRepeat: "no-repeat"
        #img.style.cursor = "crosshair" # cannot reset cursor style, as it will mess up zoom lens on iOS
  
  
  
      endZoom = (t) ->
        zoomSrc = undefined
        img.style.cursor = "url(res/cursor_rotate.cur),move"
        (document.getElementById "zoomLens360").style.display = "none"
        cache360Images nop
  
      # fullscreen {{{3
      fullScreenOriginalState = undefined
      toggleFullScreen = (e)->
        scaleFactor = Math.min(window.innerWidth / width, window.innerHeight / height)
        e.preventDefault()
        e.stopPropagation()
  
        if fullScreenOriginalState
          setStyle elem,
            fullScreenOriginalState
          fullScreenOriginalState = undefined
        else
          style = elem.style
          fullScreenOriginalState =
            position: style.position
            top: style.top
            left: style.top
            zoom: style.zoom
            transform: style.transform
            webkitTransform: style.webkitTransform
            transformOrigin: style.transformOrigin
            webkitTransformOrigin: style.webkitTransformOrigin
            margin: style.margin
            padding: style.padding
          scaleStr = "scale(#{scaleFactor}, #{scaleFactor})"
          widthPad = ((window.innerWidth  / (scaleFactor * width)) - 1)/2 * width
          heightPad = ((window.innerHeight  / (scaleFactor * height)) - 1)/2 * height
          setStyle elem,
            margin: "0"
            padding: "#{heightPad}px #{widthPad}px #{heightPad}px #{widthPad}px"
            position: "fixed"
            top: "0px"
            left: "0px"
          if style.transform == "" || style.webkitTransform == ""
            setStyle elem,
              transform: scaleStr
              webkitTransform: scaleStr
              transformOrigin: "0 0"
              webkitTransformOrigin: "0 0"
          else
            elem.style.zoom = scaleFactor
        updateImage()
        false
#{{{1 development server/page 
if isDevServer then do ->
  sa = require "solapp"
  exports.main = (solapp) ->
    # actual htmlcontent, defined as json
    solapp.setContent ["div"
      ["center"
          style:
            width: 500
            height: 500
        ["span#threesixtyproduct", {style: {background: "#ccc"}}]]]
    # invoke the threesixty component
    onetwo360
      elem_id: "threesixtyproduct"
      product_id: "lukub2ip"
      request_width: 600
      request_height: 400

  # {{{2 experiments
  sleep 1, ->
    blah = document.createElement "div"
    document.body.appendChild blah
    blah.innerHTML = Date.now()
    setInterval (->
      blah.innerHTML = "#{window.innerHeight} #{window.innerWidth} #{body.scrollTop} #{body.scrollLeft}"
    ), 1000

