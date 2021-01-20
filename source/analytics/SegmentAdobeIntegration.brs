' Constructor
'
' Factory to generate SegmentAdobeIntegration instance for Adobe Analytics destination
'
' Required params:
' @setting integration Segment settings 
' @analytics SegmentAnalytics instance
function SegmentAdobeIntegrationFactory(settings as Object, analytics as Object) as object
  return SegmentAdobeIntegration(settings, analytics, analytics.log)
end function

' Constructor
'
' Adobe Analytics destination integration
'
' Required params:
' @settings Segment Adobe Analytics integration settings
' @analytics Segment SegmentAnalytics instance
' @log message logger
function SegmentAdobeIntegration(settings as Object, analytics as Object, log as Object) as Object
  updatedSettings = _SegmentAdobeIntegration_configDefaultSettings(settings)

  this = {
    'public functions
    identify: SegmentAdobeIntegration_identify
    track: SegmentAdobeIntegration_track
    screen: SegmentAdobeIntegration_screen
    processMessages: _SegmentAdobeIntegration_processMessages

    'public variables
    key: "Adobe Analytics"
    version: "1.0.0"

    'private functions
    _configAdobeSDK: _SegmentAdobeIntegration_configAdobeSDK
    _loadAdobeConfigFile: _SegmentAdobeIntegration_loadAdobeConfigFile
    _setIdentifiers: _SegmentAdobeIntegration_setIdentifiers
    _searchValue: _SegmentAdobeIntegration_searchValue
    _getContextData: _SegmentAdobeIntegration_getContextData
    _createMediaObject: _SegmentAdobeIntegration_createMediaObject
    _trackHeartbeatEvents: _SegmentAdobeIntegration_trackHeartbeatEvents
    _mapStandardMetaData: _SegmentAdobeIntegration_mapStandardMetaData
    _extractTrackTopLevelProps : _SegmentAdobeIntegration_extractTrackTopLevelProps
    _extractScreenTopLevelProps : _SegmentAdobeIntegration_extractScreenTopLevelProps
    _videoPlaybackQOS: _SegmentAdobeIntegration_videoPlaybackQOS
    _videoPlaybackStarted: _SegmentAdobeIntegration_videoPlaybackStarted
    _videoPlaybackPaused: _SegmentAdobeIntegration_videoPlaybackPaused
    _videoPlaybackResumed: _SegmentAdobeIntegration_videoPlaybackResumed
    _videoPlaybackCompleted: _SegmentAdobeIntegration_videoPlaybackCompleted
    _videoPlaybackExited: _SegmentAdobeIntegration_videoPlaybackExited
    _videoContentStarted: _SegmentAdobeIntegration_videoContentStarted
    _videoContentCompleted: _SegmentAdobeIntegration_videoContentCompleted
    _videoPlaybackSeekOrBufferStarted: _SegmentAdobeIntegration_videoPlaybackSeekOrBufferStarted
    _videoPlaybackSeekOrBufferCompleted: _SegmentAdobeIntegration_videoPlaybackSeekOrBufferCompleted
    _videoPlaybackInterrupted: _SegmentAdobeIntegration_videoPlaybackInterrupted
    _videoAdStarted: _SegmentAdobeIntegration_videoAdStarted
    _videoAdSkipped: _SegmentAdobeIntegration_videoAdSkipped
    _videoAdCompleted: _SegmentAdobeIntegration_videoAdCompleted
    _videoQualityUpdated: _SegmentAdobeIntegration_videoQualityUpdated


    'private variables
    _clock: createObject("roTimespan")
    _playheadUpdateInterval: updatedSettings.playheadUpdateInterval
    _log: log
    _settings: updatedSettings
    _mapEventsV2: updatedSettings.eventsV2
    _contextValues: updatedSettings.contextValues
  }

  this._configAdobeSDK()
  this._adbMobileConnector = ADBMobile().getADBMobileConnectorInstance(createObject("roSGNode", "adbmobileTask"))
  this._setIdentifiers()

  if this._log.debugEnabled then
    this._adbMobileConnector.setDebugLogging(true)
  end if

  this._playbackState = _SegmentAdobeIntegration_PlaybackState(this._clock)

  this._nextPlayheadPositionUpdate = this._playheadUpdateInterval
  this._clock.mark()

  return this
end function

' Identifies the user and device upon service startup
' Required params:
' @payload object which must include payload.userId string
function SegmentAdobeIntegration_identify(payload as Object) as Void
  if payload.userId <> invalid then
    m._adbMobileConnector.setUserIdentifier(payload.userId)
    m._log.debug("setUserIdentifier(" + payload.userId + ")")
  end if
end function

' Tracks an event from the application
' Required params:
' @payload object which must include payload.event that matches Adobe or Segment eventV2 events
function SegmentAdobeIntegration_track(payload as Object) as Void
  adobeVideoEvents = {
    "Video Playback Started": true
    "Video Playback Paused": true
    "Video Playback Playing": true
    "Video Playback Interrupted": true
    "Video Playback Buffer Started": true
    "Video Playback Buffer Completed": true
    "Video Playback Seek Started": true
    "Video Playback Seek Completed": true
    "Video Playback Resumed": true
    "Video Playback Completed": true
    "Video Playback Exited": true
    "Video Content Started": true
    "Video Content Playing": true
    "Video Content Completed": true
    "Video Ad Started": true
    "Video Ad Playing": true
    "Video Ad Skipped": true
    "Video Ad Completed": true
    "Video Quality Updated": true
  }
  if adobeVideoEvents.doesExist(payload.event) then
    m._trackHeartbeatEvents(payload)
    return 
  end if

  if m._mapEventsV2 = invalid or m._mapEventsV2.count() = 0 or not m._mapEventsV2.doesExist(payload.event) then
    m._log.debug("Event must be either configured in Adobe and in the Segment EventsV2 setting, or a Video event.")
    return
  end if

  topLevelProperties = m._extractTrackTopLevelProps(payload)
  data = m._getContextData(payload.properties, payload.context, topLevelProperties)
  m._adbMobileConnector.trackAction(m._mapEventsV2[payload.event], data)
  m._log.debug("trackAction(" + m._mapEventsV2[payload.event] + ", " + formatJson(data) + ")")
end function

' Tracks the screen the application is on
' Required params:
' @payload object which must include payload.name
function SegmentAdobeIntegration_screen(payload as Object) as Void
  if payload.name <> invalid then
    topLevelProperties = m._extractScreenTopLevelProps(payload)
    data = m._getContextData(payload.properties, payload.context, topLevelProperties)

    m._adbMobileConnector.trackState(payload.name, data)
    m._log.debug("trackState(" + payload.name + ", " + formatJson(data) + ")")
  end if
end function

'Gets called every taskCheckInterval to update playhead (if needed) and invoke Adobe SDK to process any requests
function _SegmentAdobeIntegration_processMessages() as Void
  if m._clock.totalSeconds() >= m._nextPlayheadPositionUpdate and m._playbackState._isPaused = false then
    m._adbMobileConnector.mediaUpdatePlayhead(m._playbackState.getCurrentPlaybackTime())
    m._nextPlayheadPositionUpdate = m._clock.totalSeconds() + m._playheadUpdateInterval
  end if
end function

'Check for any invalid Segment UI settings and set to default
function _SegmentAdobeIntegration_configDefaultSettings(settings as Object) as Object
  updatedSettings = settings

  if settings.contextValues = invalid or type(settings.contextValues) <> "roAssociativeArray" then
    updatedSettings.contextValues = {}
  end if

  if settings.eventsV2 = invalid or type(settings.eventsV2) <> "roAssociativeArray" then
    updatedSettings.eventsV2 = {}
  end if

  if settings.playheadUpdateInterval <> invalid or not _SegmentAdobeIntegration_isInt(settings.playheadUpdateInterval) or settings.playheadUpdateInterval < 1 then
    updatedSettings.playheadUpdateInterval = 1
  end if

  return updatedSettings
end function

'Update Adobe SDK config with Segment UI settings, write to tmp:/ and initialize Adobe SDK
function _SegmentAdobeIntegration_configAdobeSDK() as Void
  defaultAdobeConfig = m._loadAdobeConfigFile()
  updatedAdobeConfig = _SegmentAdobeIntegration_updateAdobeConfigWithSettings(defaultAdobeConfig, m._settings)

  writeAsciiFile("tmp:/ADBMobileConfig.json", formatJson(updatedAdobeConfig))
end function

'Read Adobe's config either in tmp:/ or pkg:/
function _SegmentAdobeIntegration_loadAdobeConfigFile() as Object
  fs = CreateObject("roFileSystem")
  if fs.exists("tmp:/ADBMobileConfig.json")
    tempConfig = readAsciiFile("tmp:/ADBMobileConfig.json")
    if tempConfig <> invalid AND tempConfig <> ""
      return parseJson(tempConfig)
    endif
  end if

  if fs.exists("pkg:/ADBMobileConfig.json") then
    return parseJson(readAsciiFile("pkg:/ADBMobileConfig.json"))
  end if

  m._log.error("Failed to load ADBMobileConfig.json")
  return invalid
end function

'Update default Adobe SDK config with Segment UI settings
function _SegmentAdobeIntegration_updateAdobeConfigWithSettings(defaultAdobeConfig as Dynamic, settings as Object) as Object
  if type(defaultAdobeConfig) <> "roAssociativeArray" then
    updatedAdobeConfig = {
      acquisition: {}
      audienceManager: {}
      mediaHeartbeat: {}
      marketingCloud: {}
      analytics: {}
      target: {}
      messages: []
    }
  else
    updatedAdobeConfig = defaultAdobeConfig

    if type(defaultAdobeConfig.acquisition) <> "roAssociativeArray" then
      updatedAdobeConfig.acquisition = {}
    end if
    if type(defaultAdobeConfig.audienceManager) <> "roAssociativeArray" then
      updatedAdobeConfig.audienceManager = {}
    end if
    if type(defaultAdobeConfig.mediaHeartbeat) <> "roAssociativeArray" then
      updatedAdobeConfig.mediaHeartbeat = {}
    end if
    if type(defaultAdobeConfig.marketingCloud) <> "roAssociativeArray" then
      updatedAdobeConfig.marketingCloud = {}
    end if
    if type(defaultAdobeConfig.analytics) <> "roAssociativeArray" then
      updatedAdobeConfig.analytics = {}
    end if
    if type(defaultAdobeConfig.target) <> "roAssociativeArray" then
      updatedAdobeConfig.target = {}
    end if
    if type(defaultAdobeConfig.messages) <> "roArray" then
      updatedAdobeConfig.messages = []
    end if
  end if

  if settings.ssl = false then
    updatedAdobeConfig.mediaHeartbeat.ssl = false
  else if settings.ssl = true
    updatedAdobeConfig.mediaHeartbeat.ssl = true
  end if

  if _SegmentAdobeIntegration_isString(settings.heartbeatTrackingServerUrl) then
    updatedAdobeConfig.mediaHeartbeat.server = settings.heartbeatTrackingServerUrl
  end if

  return updatedAdobeConfig
end function

function _SegmentAdobeIntegration_setIdentifiers()
  if m._settings.lookupCI("advertisingIdentifier") <> invalid then
    m._adbMobileConnector.setAdvertisingIdentifier(m._settings.advertisingIdentifier)
    m._log.debug("advertisingIdentifier has been set")
  end if

  if m._settings.lookupCI("visitorSyncIdentifiers") <> invalid then
    m._adbMobileConnector.visitorSyncIdentifiers(m._settings.visitorSyncIdentifiers)
    m._log.debug("visitorSyncIdentifiers has been set")
  end if

  if m._settings.lookupCI("audienceDpid") <> invalid and m._settings.lookupCI("audienceDpuuid") <> invalid then
    m._adbMobileConnector.audienceSetDpidAndDpuuid(m._settings.audienceDpid, m._settings.audienceDpuuid)
    m._log.debug("audienceDpid and audienceDpuuid have been set")
  end if

  if m._settings.lookupCI("audienceSignalTraits") <> invalid then
    m._adbMobileConnector.audienceSubmitSignal(m._settings.audienceSignalTraits)
    m._log.debug("audienceSignal has been submitted")
  end if
end function

'Forward video event payload to function
function _SegmentAdobeIntegration_trackHeartbeatEvents(payload as Object) as Void
  if payload.event = "Video Playback Started" then
    m._videoPlaybackStarted(payload)
  else if payload.event = "Video Playback Paused"
    m._videoPlaybackPaused()
  else if payload.event = "Video Playback Resumed"
    m._videoPlaybackResumed()
  else if payload.event = "Video Playback Completed"
    m._videoPlaybackCompleted()
  else if payload.event = "Video Playback Exited"
    m._videoPlaybackExited()
  else if payload.event = "Video Content Started"
    m._videoContentStarted(payload)
  else if payload.event = "Video Content Completed"
    m._videoContentCompleted(payload)
  else if payload.event = "Video Playback Seek Started" or payload.event = "Video Playback Buffer Started"
    m._videoPlaybackSeekOrBufferStarted(payload)
  else if payload.event = "Video Playback Seek Completed" or payload.event = "Video Playback Buffer Completed"
    m._videoPlaybackSeekOrBufferCompleted(payload)
  else if payload.event = "Video Playback Interrupted"
    m._videoPlaybackInterrupted()
  else if payload.event = "Video Ad Started"
    m._videoAdStarted(payload)
  else if payload.event = "Video Ad Skipped"
    m._videoAdSkipped(payload)
  else if payload.event = "Video Ad Completed"
    m._videoAdCompleted(payload)
  else if payload.event = "Video Quality Updated"
    m._videoQualityUpdated(payload)
  else
    m._log.debug(payload.event + "event has not been handled")
  end if
end function

'Search for value using field path in data.properties
function _SegmentAdobeIntegration_searchValue(field as String, data as Object) as Dynamic
  if field = invalid or field.trim().len() = 0 then
    return invalid
  end if

  searchPath = field.split(".")
  currentValues = data

  for i = 0 to searchPath.count()
    path = searchPath[i]

    if path.trim().len() = 0 then
      return invalid
    end if

    if not currentValues.doesExist(path) then
      return invalid
    end if

    value = currentValues.lookup(path)
    if value = invalid then
      return invalid
    end if

    if i = searchPath.count() - 1 then
      return value
    end if

    currentValues = value
  end for

  return invalid
end function

'Map context data from Segment to Adobe and concatenate prefix to additional properties
function _SegmentAdobeIntegration_getContextData(properties as Dynamic, context as Dynamic, topLevelProps as Dynamic) as Object
  data = {}
  extraProperties = {}

  if type(properties) = "roAssociativeArray" then
    extraProperties.append(properties)
    data.append(properties)
  end if
  if type(context) = "roAssociativeArray" then
    data.append(context)
  end if
  if type(topLevelProps) = "roAssociativeArray" then
    data.append(topLevelProps)
  end if

  contextData = {}
  for each field in m._contextValues.keys()
    try 
      value = m._searchValue(field, data)
    catch e 
      value = invalid
    end try

    if value <> invalid then
      variable = m._contextValues.lookup(field)
      contextData.addReplace(variable, value)
      extraProperties.delete(field)
    end if
  end for

  return contextData
end function

'Map meta data from Segment to Adobe
function _SegmentAdobeIntegration_mapStandardMetaData(eventType as String, properties as Object) as Object
  videoMetaData = {
    "program" : m._adbMobileConnector.MEDIA_VideoMetadataKeySHOW,
    "season" : m._adbMobileConnector.MEDIA_VideoMetadataKeySEASON,
    "episode" : m._adbMobileConnector.MEDIA_VideoMetadataKeyEPISODE,
    "genre" : m._adbMobileConnector.MEDIA_VideoMetadataKeyGENRE,
    "channel" : m._adbMobileConnector.MEDIA_VideoMetadataKeyNETWORK,
    "airdate" : m._adbMobileConnector.MEDIA_VideoMetadataKeyFIRST_AIR_DATE,
    "rating": m._adbMobileConnector.MEDIA_VideoMetadataKeyRATING 
  }

  standardVideoMetaData = {}

  for each key in videoMetaData
    if properties[key] <> invalid then
      standardVideoMetaData[videoMetaData[key]] = properties[key]
      properties.delete(key)
    end if
  end for

  publisher = properties.publisher

  if (eventType = "Ad" or eventType = "Ad Break") and publisher <> invalid then
    standardVideoMetaData[m._adbMobileConnector.MEDIA_AdMetadataKeyADVERTISER] = publisher
  else if eventType = "Content" and publisher <> invalid
    standardVideoMetaData[m._adbMobileConnector.MEDIA_VideoMetadataKeyORIGINATOR] = publisher
  end if

  isLivestream = properties.livestream
  if isLivestream = true then
    standardVideoMetaData[m._adbMobileConnector.MEDIA_VideoMetadataKeySTREAM_FORMAT] = m._adbMobileConnector.MEDIA_STREAM_TYPE_LIVE
  else
    standardVideoMetaData[m._adbMobileConnector.MEDIA_VideoMetadataKeySTREAM_FORMAT] = m._adbMobileConnector.MEDIA_STREAM_TYPE_VOD
  end if

  return standardVideoMetadata
end function

'Create media objects for different media entities (Playback, Content, Ad, Ad Break)
function _SegmentAdobeIntegration_createMediaObject(properties as Object, eventType as String) as Object
  if type(properties) <> "roAssociativeArray" then
    properties = {}
  end if

  if _SegmentAdobeIntegration_isString(properties.title) then
    videoName = properties.title
  else
    videoName = ""
  end if

  if _SegmentAdobeIntegration_isInt(properties.total_length) or _SegmentAdobeIntegration_isFloat(properties.total_length) then
    length = properties.total_length
  else
    length = 0
  end if

  if _SegmentAdobeIntegration_isInt(properties.start_time) or _SegmentAdobeIntegration_isFloat(properties.start_time) then
    startTime = properties.start_time
  else
    startTime = 0
  end if
  
  if _SegmentAdobeIntegration_isInt(properties.indexPosition) then
    position = properties.indexPosition
  else
    position = 1
  end if
  
  isLivestream = properties.livestream
  streamType = m._adbMobileConnector.MEDIA_STREAM_TYPE_VOD

  if isLivestream = true then
    streamType = m._adbMobileConnector.MEDIA_STREAM_TYPE_LIVE
  end if

  if eventType = "Playback" then
    if _SegmentAdobeIntegration_isString(properties.content_asset_id) then
      mediaId = properties.content_asset_id
    else
      mediaId = ""
    end if
    mediaObject = adb_media_init_mediainfo(videoName, mediaId, length, streamType)

  else if eventType = "Content"
    mediaObject = adb_media_init_chapterinfo(videoName, position, length, startTime)

  else if eventType = "Ad Break"
    mediaObject = adb_media_init_adbreakinfo(videoName, startTime, position)

  else if eventType = "Ad"
    if _SegmentAdobeIntegration_isString(properties.asset_id) then
      adId = properties.asset_id
    else
      adId = ""
    end if
    mediaObject = adb_media_init_adinfo(videoName, adId, position, length)

  else
    m._log.debug("Event type not passed through.")
    return invalid
  end if

  mediaObject[m._adbMobileConnector.MEDIA_STANDARD_MEDIA_METADATA] = m._mapStandardMetaData(eventType, properties)

  return mediaObject
end function

'Extract predfined top level keys from payload for track events
function _SegmentAdobeIntegration_extractTrackTopLevelProps(payload as Object) as Object
  topLevelProperties = {}
  topLevelProperties.messageId = payload.messageId
  topLevelProperties.event = payload.event
  topLevelProperties.anonymousId = payload.anonymousId

  return topLevelProperties
end function

'Extract predined top level keys from payload for screen events
function _SegmentAdobeIntegration_extractScreenTopLevelProps(payload as Object) as Object
  topLevelProperties = {}
  topLevelProperties.messageId = payload.messageId
  topLevelProperties.name = payload.name
  topLevelProperties.anonymousId = payload.anonymousId

  return topLevelProperties
end function

'Create QOS object
function _SegmentAdobeIntegration_videoPlaybackQOS(properties as Object) as Object
  if properties = invalid then
      bitrate = 0
      fps = 0
      startupTime = 0
      droppedFrames = 0
  else
    if _SegmentAdobeIntegration_isInt(properties.bitrate) or _SegmentAdobeIntegration_isFloat(properties.bitrate) then
      bitrate = properties.bitrate
    else
      bitrate = 0
    end if
  
    if _SegmentAdobeIntegration_isInt(properties.startup_time) or _SegmentAdobeIntegration_isFloat(properties.startup_time)
      startupTime = properties.startup_time
    else
      startupTime = 0
    end if
  
    if _SegmentAdobeIntegration_isInt(properties.fps) or _SegmentAdobeIntegration_isFloat(properties.fps)
      fps = properties.fps
    else if _SegmentAdobeIntegration_isInt(properties.framerate) or _SegmentAdobeIntegration_isFloat(properties.framerate)
      fps = properties.framerate
    else
      fps = 0
    end if
  
    if _SegmentAdobeIntegration_isInt(properties.dropped_frames) or _SegmentAdobeIntegration_isFloat(properties.dropped_frames)
      droppedFrames = properties.dropped_frames
    else
      droppedFrames = 0
    end if
  end if

  return adb_media_init_qosinfo(bitrate, startupTime, fps, droppedFrames)
end function

function _SegmentAdobeIntegration_videoPlaybackStarted(payload as Object) as Void
  if payload.properties <> invalid and payload.properties.position <> invalid then
    playheadPosition = payload.properties.position
  else
    playheadPosition = 0
  end if

  m._playbackState.startPlayhead(playheadPosition)

  topLevelProperties = m._extractTrackTopLevelProps(payload)
  data = m._getContextData(payload.properties, payload.context, topLevelProperties)
  mediaObject = m._createMediaObject(payload.properties, "Playback")

  m._adbMobileConnector.mediaTrackSessionStart(mediaObject, data)
  m._log.debug("mediaTrackSessionStart(" + formatJson(mediaObject) + ", " + formatJson(data) + ")")
end function

function _SegmentAdobeIntegration_videoPlaybackPaused() as Void
  m._playbackState.pausePlayhead()
  m._adbMobileConnector.mediaTrackPause()
  m._log.debug("mediaTrackPause()")
end function

function _SegmentAdobeIntegration_videoPlaybackResumed() as Void
  m._playbackState.unPausePlayhead()
  m._adbMobileConnector.mediaTrackPlay()
  m._log.debug("mediaTrackPlay()")
end function

function _SegmentAdobeIntegration_videoPlaybackCompleted() as Void
  m._playbackState.pausePlayhead()
  m._adbMobileConnector.mediaTrackComplete()
  m._log.debug("mediaTrackComplete()")

  m._adbMobileConnector.mediaTrackSessionEnd()
  m._log.debug("mediaTrackSessionEnd()")
end function

function _SegmentAdobeIntegration_videoPlaybackExited() as Void
  m._playbackState.pausePlayhead()
  m._adbMobileConnector.mediaTrackSessionEnd()
  m._log.debug("mediaTrackSessionEnd()")
end function

function _SegmentAdobeIntegration_videoContentStarted(payload as Object) as Void
  if payload.properties <> invalid  then
    if _SegmentAdobeIntegration_isInt(payload.properties.position) or _SegmentAdobeIntegration_isFloat(payload.properties.position) then
      if payload.properties.position > 0 then
        m._playbackState.updatePlayheadPosition(payload.properties.position)
      end if
    end if
  end if

  topLevelProperties = m._extractTrackTopLevelProps(payload)
  data = m._getContextData(payload.properties, payload.context, topLevelProperties)
  mediaObject = m._createMediaObject(payload.properties, "Content")
  event = m._adbMobileConnector.MEDIA_CHAPTER_START

  m._adbMobileConnector.mediaTrackEvent(event, mediaObject, data)
  m._log.debug("mediaTrackEvent( " + event + ", " + formatJson(mediaObject) + ", " + formatJson(data) + ")")

  m._adbMobileConnector.mediaTrackPlay()
  m._log.debug("mediaTrackPlay()")
end function

function _SegmentAdobeIntegration_videoContentCompleted(payload) as Void
  topLevelProperties = m._extractTrackTopLevelProps(payload)
  data = m._getContextData(payload.properties, payload.context, topLevelProperties)
  mediaObject = m._createMediaObject(payload.properties, "Content")
  event = m._adbMobileConnector.MEDIA_CHAPTER_COMPLETE
  
  m._adbMobileConnector.mediaTrackEvent(event, mediaObject, data)
  m._log.debug("mediaTrackEvent( " + event + ")")
end function

function _SegmentAdobeIntegration_videoPlaybackSeekOrBufferStarted(payload as Object) as Void
  m._playbackState.pausePlayhead()

  topLevelProperties = m._extractTrackTopLevelProps(payload)
  data = m._getContextData(payload.properties, payload.context, topLevelProperties)
  mediaObject = m._createMediaObject(payload.properties, "Playback")
  
  if payload.event = "Video Playback Seek Started" then
    event = m._adbMobileConnector.MEDIA_SEEK_START
  else if payload.event = "Video Playback Buffer Started"
    event = m._adbMobileConnector.MEDIA_BUFFER_START
  end if

  m._adbMobileConnector.mediaTrackEvent(event, mediaObject, data)
  m._log.debug("mediaTrackEvent( " + event + ", " + formatJson(mediaObject) + ", " + formatJson(data) + ")")
end function

function _SegmentAdobeIntegration_videoPlaybackSeekOrBufferCompleted(payload as Object) as Void
  if payload.properties <> invalid and payload.properties.position <> invalid then
    position = payload.properties.position
  else
    position = 0
  end if

  m._playbackState.unPausePlayhead()
  m._playbackState.updatePlayheadPosition(position)

  topLevelProperties = m._extractTrackTopLevelProps(payload)
  data = m._getContextData(payload.properties, payload.context, topLevelProperties)
  mediaObject = m._createMediaObject(payload.properties, "Playback")
  
  if payload.event = "Video Playback Seek Completed" then
    event = m._adbMobileConnector.MEDIA_SEEK_COMPLETE
  else if payload.event = "Video Playback Buffer Completed"
    event = m._adbMobileConnector.MEDIA_BUFFER_COMPLETE
  end if

  m._adbMobileConnector.mediaTrackEvent(event, mediaObject, data)
  m._log.debug("mediaTrackEvent( " + event + ", " + formatJson(mediaObject) + ", " + formatJson(data) + ")")
end function

function _SegmentAdobeIntegration_videoPlaybackInterrupted() as Void
  m._playbackState.pausePlayhead()

  m._adbMobileConnector.mediaTrackPause()
  m._log.debug("mediaTrackPause()")
end function

function _SegmentAdobeIntegration_videoAdStarted(payload as Object) as Void
  topLevelProperties = m._extractTrackTopLevelProps(payload)
  data = m._getContextData(payload.properties, payload.context, topLevelProperties)
  adInfo = m._createMediaObject(payload.properties, "Ad")
  adBreakInfo = m._createMediaObject(payload.properties, "Ad Break")

  event = m._adbMobileConnector.MEDIA_AD_BREAK_START
  m._adbMobileConnector.mediaTrackEvent(event, adBreakInfo, data)
  m._log.debug("mediaTrackEvent( " + event + ", " + formatJson(adBreakInfo) + ", " + formatJson(data) + ")")

  event = m._adbMobileConnector.MEDIA_AD_START
  m._adbMobileConnector.mediaTrackEvent(event, adInfo, data)
  m._log.debug("mediaTrackEvent( " + event + ", " + formatJson(adInfo) + ", " + formatJson(data) + ")")

end function

function _SegmentAdobeIntegration_videoAdSkipped(payload) as Void
  event = m._adbMobileConnector.MEDIA_AD_SKIP
  topLevelProperties = m._extractTrackTopLevelProps(payload)
  data = m._getContextData(payload.properties, payload.context, topLevelProperties)
  adInfo = m._createMediaObject(payload.properties, "Ad")

  m._adbMobileConnector.mediaTrackEvent(event, adInfo, data)
  m._log.debug("mediaTrackEvent( " + event + ", " + formatJson(adInfo) + ", " + formatJson(data) + ")")
end function

function _SegmentAdobeIntegration_videoAdCompleted(payload) as Void
  topLevelProperties = m._extractTrackTopLevelProps(payload)
  data = m._getContextData(payload.properties, payload.context, topLevelProperties)
  adInfo = m._createMediaObject(payload.properties, "Ad")
  adBreakInfo = m._createMediaObject(payload.properties, "Ad Break")

  event = m._adbMobileConnector.MEDIA_AD_COMPLETE
  m._adbMobileConnector.mediaTrackEvent(event, adInfo, data)
  m._log.debug("mediaTrackEvent( " + event + ", " + formatJson(adInfo) + ", " + formatJson(data) + ")")

  event = m._adbMobileConnector.MEDIA_AD_BREAK_COMPLETE
  m._adbMobileConnector.mediaTrackEvent(event, adBreakInfo, data)
  m._log.debug("mediaTrackEvent( " + event + ", " + formatJson(adBreakInfo) + ", " + formatJson(data) + ")")
end function

function _SegmentAdobeIntegration_videoQualityUpdated(payload as Object) as Void
  qos = m._videoPlaybackQOS(payload.properties)
  m._adbMobileConnector.mediaUpdateQoS(qos)
  m._log.debug("mediaUpdateQoS( " + formatJson(qos) + ")")
end function

'Keeps track of playhead during media playback
function _SegmentAdobeIntegration_PlaybackState(clock) as Object
  this = {
    'public functions
    startPlayhead: _SegmentAdobeIntegration_PlaybackState_startPlayhead
    pausePlayhead: _SegmentAdobeIntegration_PlaybackState_pausePlayhead
    unPausePlayhead: _SegmentAdobeIntegration_PlaybackState_unPausePlayhead
    updatePlayheadPosition: _SegmentAdobeIntegration_PlaybackState_updatePlayheadPosition
    getCurrentPlaybackTime: _SegmentAdobeIntegration_PlaybackState_getCurrentPlaybackTime

    'private functions
    _calculateCurrentPlayheadPosition: _SegmentAdobeIntegration_PlaybackState_calculateCurrentPlayheadPosition

    'private variables
    _clock: clock
    _isPaused: true 
    _playheadPositionTime: 0
    _playheadPosition: 0
  }

  return this
end function

function _SegmentAdobeIntegration_PlaybackState_getCurrentPlaybackTime() as Double
  if m._isPaused then
    return m._playheadPosition
  end if

  return m._calculateCurrentPlayheadPosition()
end function

function _SegmentAdobeIntegration_PlaybackState_calculateCurrentPlayheadPosition() as Double
  currentTime = m._clock.totalSeconds()
  delta = currentTime - m._playheadPositionTime

  return m._playheadPosition + delta
end function

function _SegmentAdobeIntegration_PlaybackState_startPlayhead(position as Double) as Void
  m._playheadPositionTime = m._clock.totalSeconds()
  m._playheadPosition = position
  m._isPaused = false
end function

function _SegmentAdobeIntegration_PlaybackState_pausePlayhead() as Void
  m._isPaused = true
  m._playheadPosition = m._calculateCurrentPlayheadPosition()
  m._playheadPositionTime = m._clock.totalSeconds()
end function

function _SegmentAdobeIntegration_PlaybackState_unPausePlayhead() as Void
  m._isPaused = false
  m._playheadPositionTime = m._clock.totalSeconds()
end function

function _SegmentAdobeIntegration_PlaybackState_updatePlayheadPosition(position as Double) as Void
  m._playheadPositionTime = m._clock.totalSeconds()
  m._playheadPosition = position
end function

function _SegmentAdobeIntegration_isInt(value) as boolean
  return value <> invalid and getInterface(value, "ifInt") <> invalid and (type(value) = "roInt" or type(value) = "roInteger" or type(value) = "Integer")
end function

function _SegmentAdobeIntegration_isFloat(value) as boolean
  return value <> invalid and (getInterface(value, "ifFloat") <> invalid or (type(value) = "roFloat" or type(value) = "Float"))
end function

function _SegmentAdobeIntegration_isString(value) as boolean
  return value <> invalid and getInterface(value, "ifString") <> invalid
end function