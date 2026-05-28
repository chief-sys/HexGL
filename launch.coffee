$ = (_) -> document.getElementById _

init = (controlType, quality, hud, godmode) ->
  hexGL = new bkcore.hexgl.HexGL(
    document: document
    width: window.innerWidth
    height: window.innerHeight
    container: $ 'main'
    overlay: $ 'overlay'
    gameover: $ 'step-5'
    quality: quality
    difficulty: 0
    hud: hud is 1
    controlType: controlType
    godmode: godmode
    track: 'Cityscape'
  )
  window.hexGL=hexGL

  progressbar = $ 'progressbar'
  hexGL.load(
    onLoad: ->
      console.log 'LOADED.'
      hexGL.init()
      $('step-3').style.display = 'none'
      $('step-4').style.display = 'block'
      # Re-zero the gyroscope to the user's current hold position.
      hexGL.components?.shipControls?.orientationController?.recalibrate?()
      hexGL.start()
    onError: (s) ->
      console.error "Error loading #{ s }."
    onProgress: (p, t, n) ->
      console.log("LOADED "+t+" : "+n+" ( "+p.loaded+" / "+p.total+" ).")
      progressbar.style.width = "#{ p.loaded / p.total * 100 }%"
  )

u = bkcore.Utils.getURLParameter

isMobile = bkcore.Utils.isTouchDevice()

# On mobile the cycler shows [TOUCH, GYROSCOPE]; this maps the cycler
# index back to the canonical controlType ShipControls understands
# (1 = TouchController, 4 = OrientationController).
MOBILE_CONTROL_TYPE = [1, 4]

s = [
  if isMobile
    ['controlType', ['TOUCH', 'GYROSCOPE'], 0, 0, 'Controls: ']
  else
    ['controlType', ['KEYBOARD', 'TOUCH', 'LEAP MOTION CONTROLLER',
      'GAMEPAD'], 0, 0, 'Controls: ']
  ['quality', ['LOW', 'MID', 'HIGH', 'VERY HIGH'], 3, 3, 'Quality: ']
  ['hud', ['OFF', 'ON'], 1, 1, 'HUD: ']
  ['godmode', ['OFF', 'ON'], 0, 1, 'Godmode: ']
]

canonicalControlType = -> if isMobile then MOBILE_CONTROL_TYPE[s[0][3]] else s[0][3]

for a in s
  do(a)->
    a[3] = u(a[0]) ? a[2]
    e = $ "s-#{a[0]}"
    (f = -> e.innerHTML = a[4]+a[1][a[3]])()
    e.onclick = -> f(a[3] = (a[3]+1)%a[1].length)
proceedToLoad = ->
  $('step-2').style.display = 'none'
  $('step-3').style.display = 'block'
  init canonicalControlType(), s[1][3], s[2][3], s[3][3]

$('step-2').onclick = ->
  ct = canonicalControlType()
  if isMobile and ct is 4 and
      typeof DeviceOrientationEvent isnt 'undefined' and
      typeof DeviceOrientationEvent.requestPermission is 'function'
    DeviceOrientationEvent.requestPermission()
      .then (state) ->
        s[0][3] = 0 if state isnt 'granted' # fall back to TOUCH
        proceedToLoad()
      .catch ->
        s[0][3] = 0
        proceedToLoad()
    return
  proceedToLoad()
$('step-5').onclick = ->
  window.location.reload()
hasWebGL = ->
  gl = null
  canvas = document.createElement('canvas');
  try
    gl = canvas.getContext("webgl")
  if not gl?
    try
      gl = canvas.getContext("experimental-webgl")
  return gl?

setupRotateOverlay = ->
  return if not isMobile
  overlay = $('rotate-overlay')
  unless overlay?
    overlay = document.createElement 'div'
    overlay.id = 'rotate-overlay'
    overlay.innerHTML = 'ROTATE YOUR PHONE<br>TO LANDSCAPE'
    document.body.appendChild overlay
  inPlayingPhase = ->
    for id in ['step-2', 'step-3', 'step-4']
      el = $(id)
      return true if el? and el.style.display and el.style.display isnt 'none'
    false
  update = ->
    portrait = window.innerHeight > window.innerWidth
    wasShown = overlay.style.display is 'flex'
    if portrait and inPlayingPhase()
      overlay.style.display = 'flex'
    else
      overlay.style.display = 'none'
      # Rotated into landscape — make this orientation the new gyro neutral.
      if wasShown
        window.hexGL?.components?.shipControls?.orientationController?.recalibrate?()
  window.addEventListener 'resize', update
  window.addEventListener 'orientationchange', update
  update()

requestMobileFullscreen = ->
  el = document.documentElement
  req = el.requestFullscreen ? el.webkitRequestFullscreen ? el.mozRequestFullScreen ? el.msRequestFullscreen
  if req?
    try
      p = req.call(el)
      p.catch(->) if p?.catch?
    catch e
      # ignore
  if window.screen?.orientation?.lock?
    try screen.orientation.lock('landscape').catch(->) catch e then # ignore

paintStep2Help = ->
  step2 = $('step-2')
  existing = $('gyro-help-msg')
  existing.parentNode.removeChild(existing) if existing?.parentNode
  ct = canonicalControlType()
  if ct is 4
    step2.style.backgroundImage = 'none'
    msg = document.createElement 'div'
    msg.id = 'gyro-help-msg'
    msg.className = 'gyro-help'
    msg.innerHTML = 'TILT YOUR PHONE TO STEER<br>HOLD TO ACCELERATE<br><br>TAP TO START'
    step2.appendChild msg
  else
    step2.style.backgroundImage = "url(css/help-#{ct}.png)"

if not hasWebGL()
  getWebGL = $('start')
  getWebGL.innerHTML = 'WebGL is not supported!'
  getWebGL.onclick = ->
    window.location.href = 'http://get.webgl.org/'
else
  $('start').onclick = ->
    if isMobile
      requestMobileFullscreen()
      setupRotateOverlay()
    $('step-1').style.display = 'none'
    $('step-2').style.display = 'block'
    paintStep2Help()
