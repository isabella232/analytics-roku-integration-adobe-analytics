function init()
  m.appInfo = CreateObject("roAppInfo")
  writeKey = m.appInfo.GetValue("analytics_write_key")
  if writeKey = "" then
    print "********** ERROR: writeKey is not defined. Exiting. **********"
    ExitUserInterface()
  endif

  task = m.top.findNode("analyticsTask")
  m.library = SegmentAnalyticsConnector(task)

  config = {
    writeKey: writeKey
    debug: false
  }
  m.library.init(config)
  
  findViews()
  setListeners()
  setContent()
  startUpEvents()
end function

sub findViews()
  m.top.setFocus(true)
  m.video = m.top.findNode("VideoPlayer")
  m.helloLabel = m.top.findNode("helloLabel")
  m.statusLabel = m.top.findNode("statusLabel")
  m.actionLabel = m.top.findNode("actionLabel")
end sub

sub setListeners()
  m.video.observeField("state", "onVideoPlaybackStateChange")
  m.video.observeField("contentIndex", "onContentChange")
end sub

sub setContent()
  m.global.id = "new id"
  m.global.addFields({helloLabel: m.helloLabel, statusLabel: m.statusLabel
                      actionLabel: m.actionLabel})

  m.helloLabel.font.size=100
  m.helloLabel.color="0x49B882"

  m.actionLabel.color="0x72D7EE"
  m.actionLabel.font.size=20

  m.statusLabel.text = "Application Opened"
  m.statusLabel.color="0xFFFFFF"
  m.statusLabel.font.size=15

  videoContent = createObject("RoSGNode", "ContentNode")
  videoContent.url = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
  videoContent.title = "Test Video"
  videoContent.streamformat = "hls"

  adContent = createObject("RoSGNode", "ContentNode")
  adContent.url = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
  adContent.title = "Test Ad"
  adContent.streamformat = "hls"
  adContent.bookmarkPosition = 633

  playlist = createObject("RoSGNode", "ContentNode")
  playlist.appendChild(adContent)
  playlist.appendChild(videoContent)
  m.video.content = playlist
end sub

function startUpEvents()
  m.userId = "sampleUser"
  m.options = {
    userId: m.userId
    integrations: { "Adobe Analytics": true}
    context: {contextTestProperty: "test"}
  }
  m.metaData = {
    program: "testProgram"
    season: "testSeason"
    episode: "testEpisode"
    genre: "testGenre"
    channel: "testChannel"
    airdate: "testAirDate"
    rating: "testRating"
    publisher: "testPublisher"
  }
  m.library.identify(m.userId, {"email": "sampleuser@example.com"}, createOptions())
  print "######## Identity Set"
  'm.library.track("Application Opened", invalid, m.options)
  'print "######## Application Opened"
  'm.library.screen("Startup screen", invalid, invalid, m.options)
  'print "######## Startup Screen"
end function

function onKeyEvent(key as String, press as Boolean) as Boolean
  handled = false
  if press then
    if key = "back" and m.video.visible = true then
      removeVideoPlayback()
      handled = true
    else if key = "OK" and m.video.visible = false
      startVideoPlayback()
      handled = true
    else if m.video.visible = false
      m.library.track(key + " key pressed", invalid, createOptions())
      handled = true
    end if
  end if
  return handled
end function

function removeVideoPlayback() as Void
  m.video.control = "stop"
  m.video.visible = false
  m.video.setFocus(false)
  m.top.setFocus(true)
end function

function startVideoPlayback() as Void
  m.video.visible = true
  m.video.control = "play"

  m.library.track("Video Playback Started", createPlaybackProps(), createOptions())
  print "######## Video Playback Started"
  m.video.setFocus(true)
end function

function onVideoPlaybackStateChange()
  state =  m.video.state

  if m.prevState = "buffering" and state = "playing" then
    m.library.track("Video Playback Buffer Completed", createPlaybackProps(), createOptions())
    print "######## Video Playback Buffer Completed"
  end if

  if state = "playing" and m.hasStarted = invalid then
    m.library.track("Video Ad Started", createAdProps(), createOptions())
    print "######## Video Ad Started"
    m.hasStarted = true
    
  else if state = "playing" and m.prevState = "paused"
    m.library.track("Video Playback Resumed", invalid, createOptions())
    print "######## Video Playback Resumed"

  else if state = "buffering"
    m.library.track("Video Playback Buffer Started", createPlaybackProps(), createOptions())
    print "######## Video Playback Buffer Started"

  else if state = "paused"
    m.library.track("Video Playback Paused", invalid, createOptions())
    print "######## Video Playback Paused"

  else if state = "finished"
    m.library.track("Video Content Completed", invalid, createOptions())
    print "######## Video Content Completed"
    m.library.track("Video Playback Completed", invalid, createOptions())
    print "######## Video Playback Completed"
    removeVideoPlayback()

  else if state = "stopped"
    m.library.track("Video Playback Exited", invalid, createOptions())
    print "######## Video Playback Exited"

  else if state = "error"
    m.library.track("Video Playback Interrupted", invalid, createOptions())
    print "######## Video Playback Interrupted"
  end if

  m.prevState = state
end function

function onContentChange()
  'Pre-roll ad has completed and content is now playing
  if m.video.contentIndex = 1 then
    m.library.track("Video Ad Completed", createAdProps(), createOptions())
    print "######## Video Ad Completed"

    m.library.track("Video Content Started", createContentProps(), createOptions())
    print "######## Video Content Started"
  end if
end function

function createOptions(optionData = invalid)
  options = {}
  options.append(m.options)

  if optionData <> invalid then
    options.append(optionData)
  end if

  return options
end function

function createAdProps()
  props = {
    title: "Test Ad"
    asset_id: "testAdAsset"
    position: m.video.position
    indexPosition: 1
    start_time: 1607373968
    total_length: 3
    extraProperty: "testExtraProperty"
  }
  props.append(m.metaData)

  return props
end function

function createAdSkippedProps()
  props = {
    title: "Test Ad"
    asset_id: "testAdAsset"
    position: m.video.position
    start_time: 1607373968
    extraProperty: "testExtraProperty"
  }
  props.append(m.metaData)

  return props
end function

function createPlaybackProps()
  props = {
    livestream: false
    title: "Test Video"
    total_length: 643
    content_asset_id: "testContentAssetId"
    extraProperty: "testExtraProperty"
  }
  props.append(m.metaData)

  return props
end function

function createQualityUpdatedProps()
  if m.video.streamInfo <> invalid then
    bitrate = m.video.streamInfo.measuredBitrate
  else
    bitrate = invalid
  end if

  props = {
    bitrate: bitrate
    startup_time: m.video.timeToStartStreaming
    fps: 24
    dropped_frames: 0
  }
  props.append(m.metaData)

  return props
end function

function createContentProps()
  props = {
    title: "Test Video"
    position: m.video.position
    indexPosition: 1
    total_length: 634
    start_time: 1607373968
    extraProperty: "testExtraProperty"
  }
  props.append(m.metaData)

  return props
end function
