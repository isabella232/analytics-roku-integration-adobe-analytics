'@TestSuite [SAIT] Segment Adobe Integration Tests

'@Setup
function SAIT_setup() as void
    m.allowNonExistingMethodsOnMocks = false
    m.settings = {
      contextValues: {
      "messageId": "adb_id",
      },
      eventsV2: { "testEvent": "adobeEvent"},
    }
    m.logger = {
      debugEnabled: false
      debug: function(message as String) as Boolean
        return m._log(message, "DEBUG")
      end function
      error: function(message as String) as Boolean
        return m._log(message, "ERROR")
      end function
      _log: function(message as String, logLevel = "NONE" as String) as Boolean
        showDebugLog = invalid
        if m.debugEnabled <> invalid then
          showDebugLog = m.debugEnabled
        end if
    
        if logLevel = "DEBUG" and (showDebugLog = invalid or not showDebugLog) then
          return false
        end if
        print "SegmentAnalytics - [" + logLevel + "] " + message
        return true
      end function
    }
    m.clock = {
      time: 0
      wait: function(seconds)
          m.time = m.time + seconds
          return m.time
        end function
      totalSeconds: function()
          return m.time
        end function
    }
end function

'@BeforeEach
function SAIT_BeforeEach() as void
  m.adobeIntegration = SegmentAdobeIntegration(m.settings, {}, m.logger)
  m.adobeIntegration._clock = m.clock
  m.adobeIntegration._playbackState._clock = m.clock
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test valid initial constructor
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test basic constructor values
function SAIT__constructor_basic_success_initial() as void
  m.AssertEqual(m.adobeIntegration.key, "Adobe Analytics")
  m.AssertEqual(type(m.adobeIntegration.version), "roString")
  m.AssertEqual(m.adobeIntegration._settings, m.settings)
  m.AssertEqual(m.adobeIntegration._mapEventsV2, m.settings.eventsV2)
  m.AssertEqual(m.adobeIntegration._contextValues, m.settings.contextValues)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test other valid constructor values
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test basic constructor values
'@Params[{}, {"eventsV2": {}, "contextValues": {}, "playheadUpdateInterval": 1}]
function SAIT__constructor_basic_success_otherValues(settings, expected) as void
  adobeIntegration = SegmentAdobeIntegration(settings, {}, m.logger)

  m.AssertEqual(adobeIntegration._settings, expected)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test identify call works as expected
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test identify
'@Params[{"userId": "testUserId", "traits": null, "options": null}]
function SAIT__identify(payload) as void
  m.ExpectOnce(m.adobeIntegration._adbMobileConnector, "setUserIdentifier", [payload.userId])
  m.adobeIntegration.identify(payload)
end function
  
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It tests screen call works as expected
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test screen
'@Params[{"name": "screen", "messageId": "test", "properties": {}, context: {}}, {"adb_id": "test"}]
function SAIT__screen(payload, expectedContext) as void
  m.ExpectOnce(m.adobeIntegration._adbMobileConnector, "trackState", [payload.name, expectedContext])
  m.adobeIntegration.screen(payload)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test track call with a valid event
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure events set in Segment UI settings (eventsV2) can be sent out
'@Params[{"event": "testEvent", "messageId": "test", "properties": {}, "context": {}}, {"adb_id": "test"}]
function SAIT__track_validEvent(payload, expectedContext) as void
  m.ExpectNone(m.adobeIntegration, "_trackHeartbeatEvents")
  m.ExpectOnce(m.adobeIntegration._adbMobileConnector, "trackAction", [m.adobeIntegration._mapEventsV2[payload.event], expectedContext])
  m.adobeIntegration.track(payload)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test track call with invalid events
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure invalid events are ignored gracefully
'@Params[{"event": "unknown", "messageId": "test", "properties": {}, "context": {}}]
function SAIT__track_invalidEvent(payload) as void
  m.ExpectNone(m.adobeIntegration, "_trackHeartbeatEvents")
  m.ExpectOnce(m.adobeIntegration._log, "debug")
  m.adobeIntegration.track(payload)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test processMessages mediaUpdatePlayhead
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure playhead position is updated when timer has passed the nextPlayheadPositionUpdate time
function SAIT__processMessages_updatePlayhead_updateReady() as void
  m.adobeIntegration._playbackState.startPlayhead(0)
  m.adobeIntegration._playbackState._clock.wait(1)
  m.ExpectOnce(m.adobeIntegration._adbMobileConnector, "mediaUpdatePlayhead", [m.adobeIntegration._playbackState.getCurrentPlaybackTime()])
  m.adobeIntegration.processMessages()
  m.AssertEqual(m.adobeIntegration._nextPlayheadPositionUpdate, 2)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test processMessages mediaUpdatePlayhead not ready
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure playhead position update time is not updated when timer hasn't reached nextPlayheadPosition update time
function SAIT__processMessages_updatePlayhead_notReady() as void
  m.adobeIntegration._nextPlayheadPositionUpdate = 1
  m.adobeIntegration._playbackState.startPlayhead(0)
  m.ExpectNone(m.adobeIntegration._adbMobileConnector, "mediaUpdatePlayhead")
  m.adobeIntegration.processMessages()
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test processMessages mediaUpdatePlayhead playhead paused
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure playhead position update time is not updated when playhead is paused
function SAIT__processMessages_updatePlayhead_paused() as void
  m.adobeIntegration._playbackState._clock.wait(1)
  m.ExpectNone(m.adobeIntegration._adbMobileConnector, "mediaUpdatePlayhead")
  m.adobeIntegration.processMessages()
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test configAdobeSDK using pkg file
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure Adobe SDK config is updated using pkg:/ADBMobileConfig.json and Segment UI settings
'@Params[{"ssl": true, "heartbeatTrackingServerUrl": "test"}]
'@Params[{"ssl": false, "heartbeatTrackingServerUrl": "test1"}]
function SAIT__configAdobeSDK_usingPkgFile(settings) as void
  m.adobeIntegration._settings = settings
  m.adobeIntegration._configAdobeSDK()
  're-initialize config object in globalAA
  _adb_config()._init()
  tmpConfig = _adb_config()._config

  m.AssertEqual(tmpConfig.mediaHeartbeat.ssl, settings.ssl)
  m.AssertEqual(tmpConfig.mediaHeartbeat.server, settings.heartbeatTrackingServerUrl)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test configAdobeSDK with tmp file previously saved
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure Adobe SDK config is updated using tmp:/ADBMobileConfig.json and Segment UI settings
'@Params[{"ssl": true, "heartbeatTrackingServerUrl": "test", "marketingCloudOrgId": "test", "trackingServerUrl": "test", "reportSuiteId": "id"}]
'@Params[{"ssl": false, "heartbeatTrackingServerUrl": "test1", "marketingCloudOrgId": "test1", "trackingServerUrl": "test1", "reportSuiteId": "id"}]
function SAIT__configAdobeSDK_usingTmpFile(settings) as void
  defaultAdobeConfig = parseJson(readAsciiFile("pkg:/ADBMobileConfig.json"))
  defaultAdobeConfig.mediaHeartbeat.ssl = settings.ssl
  defaultAdobeConfig.mediaHeartbeat.server = settings.heartbeatTrackingServerUrl
  defaultAdobeConfig.marketingCloud.org = settings.marketingCloudOrgId
  defaultAdobeConfig.marketingCloud.server = settings.trackingServerUrl
  defaultAdobeConfig.analytics.server = settings.trackingServerUrl
  defaultAdobeConfig.analytics.rsids = settings.reportSuiteId
  defaultAdobeConfig.test = "test"
  writeAsciiFile("tmp:/ADBMobileConfig.json", formatJson(defaultAdobeConfig))

  m.adobeIntegration._settings = settings
  m.adobeIntegration._configAdobeSDK()
  're-initialize config object in globalAA
  _adb_config()._init()
  tmpConfig = _adb_config()._config

  m.AssertEqual(tmpConfig.test, "test")
  m.AssertEqual(tmpConfig.mediaHeartbeat.ssl, settings.ssl)
  m.AssertEqual(tmpConfig.mediaHeartbeat.server, settings.heartbeatTrackingServerUrl)
  m.AssertEqual(tmpConfig.marketingCloud.org, settings.marketingCloudOrgId)
  m.AssertEqual(tmpConfig.marketingCloud.server, settings.trackingServerUrl)
  m.AssertEqual(tmpConfig.analytics.server, settings.trackingServerUrl)
  m.AssertEqual(tmpConfig.analytics.rsids, settings.reportSuiteId)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test updateAdobeConfigWithSettings
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure updated Adobe SDK config meets default requirements
'@Params[null, {"acquisition":{},"analytics":{},"audiencemanager":{},"marketingcloud":{},"mediaheartbeat":{"server":"testServer","ssl":false},"messages":[],"target":{}}]
'@Params[{}, {"acquisition":{},"analytics":{},"audiencemanager":{},"marketingcloud":{},"mediaheartbeat":{"server":"testServer","ssl":false},"messages":[],"target":{}}]
'@Params[{"target": {"clientCode": "test"}}, {"acquisition":{},"analytics":{},"audiencemanager":{},"marketingcloud":{},"mediaheartbeat":{"server":"testServer","ssl":false},"messages":[],"target":{"clientCode": "test"}}]
function SAIT__updateAdobeConfigWithSettings(defaultAdobeConfig, expected) as void
  settings = {
    ssl: false
    heartbeatTrackingServerUrl: "testServer"
  }
  updatedAdobeConfig = _SegmentAdobeIntegration_updateAdobeConfigWithSettings(defaultAdobeConfig, settings)
  m.AssertEqual(updatedAdobeConfig, expected)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test searchValue
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure contextData is used to translate payload data to context value using dot-notation fields
'@Params["testSegmentContext", {"testSegmentContext": "testValue"}, "testValue"]
'@Params["testField.testKey", {"testField": {"testKey": "testValue"}}, "testValue"]
'@Params["testField.testKey.testSubKey", {"testField": {"testKey": {"testSubKey": "testValue"}}}, "testValue"]
function SAIT__searchValue(field, data, expected) as void
  translatedValue = m.adobeIntegration._searchValue(field, data)
  m.AssertEqual(translatedValue, expected)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test searchValue with invalid field
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure invalid is returned if field does not exists
'@Params["", {"": "testValue"}, "testValue"]
'@Params[".", {"testSegmentContext": "testValue"}, "testValue"]
'@Params[".testSegmentContext", {".testSegmentContext": "testValue"}, "testValue"]
'@Params["testField..testKey", {"testField.": {"testKey": "testValue"}}, "testValue"]
'@Params["testField.testKey.testSubKey.", {"testField": {"testKey": {"testSubKey.": "testValue"}}}, "testValue"]
function SAIT__searchValue_invalid(field, data, expected) as void
  translatedValue = m.adobeIntegration._searchValue(field, data)
  m.AssertEqual(translatedValue, invalid)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test getContextData properties
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure context data in properties is correctly translated using Segment's contextValues
'@Params[{}, {}, {}]
'@Params[{"testSegmentContext": "translatedContext"}, {"extraProperty": "testValue"}, {}]
'@Params[{"testSegmentContext": "translatedContext"}, {"testSegmentContext": "testValue"}, {"translatedContext": "testValue"}]
function SAIT__getContextData_properties(contextValues, properties, expected) as void
  m.adobeIntegration._contextValues = contextValues

  contextData = m.adobeIntegration._getContextData(properties, {}, {})
  m.AssertEqual(contextData, expected)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test getContextData context
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure context data in context is correctly translated using Segment's contextValues
'@Params[{}, {}, {}]
'@Params[{"testSegmentContext": "translatedContext"}, {"extraProperty": "testValue"}, {}]
'@Params[{"testSegmentContext": "translatedContext"}, {"testSegmentContext": "testValue"}, {"translatedContext": "testValue"}]
function SAIT__getContextData_context(contextValues, context, expected) as void
  m.adobeIntegration._contextValues = contextValues

  contextData = m.adobeIntegration._getContextData(properties, context, topLevelProps)
  m.AssertEqual(contextData, expected)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test getContextData topLevelProps
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure context data in topLevelProps is correctly translated using Segment's contextValues
'@Params[{}, {}]
'@Params[{"messageId": "m", "event": "e", "anonymousId": "a", "name": "n"}, {"m": "testMessageId", "e": "testEvent", "a": "testAnonymousId", "n": "testName"}]
function SAIT__getContextData_topLevelProps(contextValues, expected) as void
  m.adobeIntegration._contextValues = contextValues
  topLevelProps = {
    messageId: "testMessageId" 
    event: "testEvent"
    anonymousId: "testAnonymousId"
    name: "testName"
    extra: "invalid top level prop"
  }
  contextData = m.adobeIntegration._getContextData({}, {}, topLevelProps)

  m.AssertEqual(contextData, expected)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test getContextData with no data
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure an empty object is return if input is invalid
function SAIT__getContextData_Empty() as void
  contextData = m.adobeIntegration._getContextData(invalid, invalid, invalid)
  m.AssertEqual(contextData, {})
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test createMediaObject
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure an invalid mediaObject is returned when passed in event does not exists
function SAIT__createMediaObject_invalidEvent() as void
  mediaObject = m.adobeIntegration._createMediaObject(invalid, "Unknown")
  m.AssertEqual(mediaObject, invalid)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test createMediaObject for Playback events
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure a valid mediaObject is returned for any input
'@Params[null, {"id": "", "length": 0, "mediaType": "video", "name": "", "streamType": "vod"}]
'@Params[{"title": "testName", "total_length": 550, "content_asset_id": "testMediaId", "livestream": true}, {"id": "testMediaId", "length": 550, "mediaType": "video", "name": "testName", "streamType": "live"}]
function SAIT__createMediaObject_playback(properties, expected) as void
  mediaObject = m.adobeIntegration._createMediaObject(properties, "Playback")
  m.AssertEqual(mediaObject.id, expected.id)
  m.AssertEqual(str(mediaObject.length), strI(expected.length))
  m.AssertEqual(mediaObject.mediaType, expected.mediaType)
  m.AssertEqual(mediaObject.name, expected.name)
  m.AssertEqual(mediaObject.streamType, expected.streamType)
  m.AssertEqual(type(mediaObject.media_standard_content_metadata), "roAssociativeArray")
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test createMediaObject for Content events
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure a valid mediaObject is returned for any input
'@Params[null, {"indexPosition": 1, "length": 0, "offset": 0, "name": ""}]
'@Params[{"indexPosition": 34, "total_length": 89, "start_time": 20, "title": "testName"}, {"indexPosition": 34, "length": 89, "offset": 20, "name": "testName"}]
function SAIT__createMediaObject_content(properties, expected) as void
  mediaObject = m.adobeIntegration._createMediaObject(properties, "Content")
  m.AssertEqual(str(mediaObject.length), strI(expected.length))
  m.AssertEqual(str(mediaObject.position), strI(expected.indexPosition))
  m.AssertEqual(mediaObject.name, expected.name)
  m.AssertEqual(str(mediaObject.offset), strI(expected.offset))
  m.AssertEqual(type(mediaObject.media_standard_content_metadata), "roAssociativeArray")
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test createMediaObject for Ad Break events
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure a valid mediaObject is returned for any input
'@Params[null, {"indexPosition": 1, "startTime": 0, "name": ""}]
'@Params[{"indexPosition": 34, "start_time": 20, "title": "testName"}, {"indexPosition": 34, "startTime": 20, "name": "testName"}]
function SAIT__createMediaObject_adBreak(properties, expected) as void
  mediaObject = m.adobeIntegration._createMediaObject(properties, "Ad Break")
  m.AssertEqual(str(mediaObject.startTime), strI(expected.startTime))
  m.AssertEqual(str(mediaObject.position), strI(expected.indexPosition))
  m.AssertEqual(mediaObject.name, expected.name)
  m.AssertEqual(type(mediaObject.media_standard_content_metadata), "roAssociativeArray")
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test createMediaObject for Ad events
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure a valid mediaObject is returned for any input
'@Params[null, {"id": "", "indexPosition": 1, "length": 0, "name": ""}]
'@Params[{"indexPosition": 34, "total_length": 20, "asset_id": "testAssetId", title: "testName"}, {"indexPosition": 34, "length": 20, "id": "testAssetId", "name": "testName"}]
function SAIT__createMediaObject_ad(properties, expected) as void
  mediaObject = m.adobeIntegration._createMediaObject(properties, "Ad")
  m.AssertEqual(str(mediaObject.length), strI(expected.length))
  m.AssertEqual(str(mediaObject.position), strI(expected.indexPosition))
  m.AssertEqual(mediaObject.id, expected.id)
  m.AssertEqual(mediaObject.name, expected.name)
  m.AssertEqual(type(mediaObject.media_standard_content_metadata), "roAssociativeArray")
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test Video Playback Resumed/Seek Completed/Buffer Completed event resumes playback state
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure playhead is resumed
'@Params[{"event": "Video Playback Resumed"}]
'@Params[{"event": "Video Playback Seek Completed"}]
'@Params[{"event": "Video Playback Buffer Completed"}]
function SAIT__trackVideo_videoPlayback_unpausePlayhead(payload) as void
  m.stub(m.adobeIntegration._adbMobileConnector, "mediaTrackPlay")
  m.stub(m.adobeIntegration._adbMobileConnector, "mediaTrackEvent")
  m.stub(m.adobeIntegration._playbackState, "updatePlayheadPosition", true)
  
  m.adobeIntegration._playbackState.startPlayhead(0)

  m.adobeIntegration._playbackState._clock.wait(1)
  m.adobeIntegration._playbackState.pausePlayhead()
  m.adobeIntegration.track(payload)

  m.adobeIntegration._playbackState._clock.wait(1)

  currentPosition = m.adobeIntegration._playbackState.getCurrentPlaybackTime()

  m.AssertEqual(m.adobeIntegration._playbackState._isPaused, false)
  m.AssertEqual(strI(currentPosition), strI(2))
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test Video Playback Started event starts playback state
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure playhead is started
'@Params[{"event": "Video Playback Started", properties: {}}]
'@Params[{"event": "Video Playback Started", properties: {"position": 0}}]
'@Params[{"event": "Video Playback Started", properties: {"position": 1}}]
'@Params[{"event": "Video Playback Started", properties: {"position": 1.5}}]
function SAIT__trackVideo_videoPlayback_startPlayhead(payload) as void
  m.stub(m.adobeIntegration._adbMobileConnector, "mediaTrackSessionStart")

  m.AssertEqual(m.adobeIntegration._playbackState._isPaused, true)
  m.adobeIntegration.track(payload)
  m.adobeIntegration._playbackState._clock.wait(1)

  if payload.properties.position = invalid then
    position = 0
  else
    position = payload.properties.position
  end if

  currentPosition = m.adobeIntegration._playbackState.getCurrentPlaybackTime()

  m.AssertEqual(m.adobeIntegration._playbackState._isPaused, false)
  m.AssertEqual(strI(currentPosition), strI(1 + position))
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test Video Playback Paused/Completed/Seek Started/Buffer Started/Interupted event pauses playback state
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure playhead is paused
'@Params[{"event": "Video Playback Paused"}]
'@Params[{"event": "Video Playback Completed"}]
'@Params[{"event": "Video Playback Seek Started"}]
'@Params[{"event": "Video Playback Buffer Started"}]
'@Params[{"event": "Video Playback Interrupted"}]
'@Params[{"event": "Video Playback Exited"}]
function SAIT__trackVideo_videoPlayback_pausePlayhead(payload) as void
  m.stub(m.adobeIntegration._adbMobileConnector, "mediaTrackPause")
  m.stub(m.adobeIntegration._adbMobileConnector, "mediaTrackComplete")
  m.stub(m.adobeIntegration._adbMobileConnector, "mediaTrackSessionEnd")
  m.stub(m.adobeIntegration._adbMobileConnector, "mediaTrackSessionEnd")
  m.stub(m.adobeIntegration._adbMobileConnector, "mediaTrackEvent")

  m.adobeIntegration._playbackState.startPlayhead(0)
  m.AssertEqual(m.adobeIntegration._playbackState._isPaused, false)

  m.adobeIntegration._playbackState._clock.wait(1)
  m.adobeIntegration.track(payload)
  currentPosition = m.adobeIntegration._playbackState.getCurrentPlaybackTime()

  m.adobeIntegration._playbackState._clock.wait(1)

  m.AssertEqual(m.adobeIntegration._playbackState._isPaused, true)
  m.AssertEqual(strI(currentPosition), strI(1))
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test Video Playback Buffer/Seek Completed event updates playback state
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure playhead is resumed and updated
'@Params[{"event": "Video Playback Seek Completed", properties: {}}]
'@Params[{"event": "Video Playback Seek Completed", properties: {"position": 0}}]
'@Params[{"event": "Video Playback Seek Completed", properties: {"position": 1}}]
'@Params[{"event": "Video Playback Seek Completed", properties: {"position": 1.5}}]
'@Params[{"event": "Video Playback Buffer Completed", properties: {}}]
'@Params[{"event": "Video Playback Buffer Completed", properties: {"position": 0}}]
'@Params[{"event": "Video Playback Buffer Completed", properties: {"position": 1}}]
'@Params[{"event": "Video Playback Buffer Completed", properties: {"position": 1.5}}]
'@Params[{"event": "Video Content Started", properties: {}}]
'@Params[{"event": "Video Content Started", properties: {"position": 0}}]
'@Params[{"event": "Video Content Started", properties: {"position": 1}}]
'@Params[{"event": "Video Content Started", properties: {"position": 1.5}}]
function SAIT__trackVideo_videoPlaybackPaused_updatedPlayhead(payload) as void
  m.stub(m.adobeIntegration._adbMobileConnector, "mediaTrackEvent")
  m.stub(m.adobeIntegration._adbMobileConnector, "mediaUpdatePlayhead")
  m.stub(m.adobeIntegration._adbMobileConnector, "mediaTrackPlay")

  m.adobeIntegration._playbackState.startPlayhead(0)
  m.adobeIntegration.track(payload)

  m.adobeIntegration._playbackState._clock.wait(1)
  currentPosition = m.adobeIntegration._playbackState.getCurrentPlaybackTime()

  if payload.properties.position = invalid then
    position = 0
  else
    position = payload.properties.position
  end if

  m.AssertEqual(m.adobeIntegration._playbackState._isPaused, false)
  m.AssertEqual(strI(currentPosition), strI(position + 1))
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test Video Playback Started event
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure ADBMobile mediaTrackSessionStart gets invoked with correct payload
'@Params[{"messageId": "id", "event": "Video Playback Started", "context": {}, "properties": {"position":1, "title":"n", "total_length":1.5, "content_asset_id":"a"}}, {"name":"n", "media_standard_content_metadata":{"a.media.format":"vod"}, "length":1.5, "mediatype":"video", "streamtype":"vod", "id":"a"}, {"adb_id":"id"}]
function SAIT__trackVideo_videoPlaybackStarted(payload, mediaObject, data) as void
  m.ExpectOnce(m.adobeIntegration._adbMobileConnector, "mediaTrackSessionStart", [mediaObject, data])
  m.adobeIntegration.track(payload)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test Video Playback Paused/Interupted event
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure ADBMobile mediaTrackPause gets invoked
'@Params[{"event": "Video Playback Paused"}]
'@Params[{"event": "Video Playback Interrupted"}]
function SAIT__trackVideo_videoPlaybackPausedInterrupted(payload) as void
  m.ExpectOnce(m.adobeIntegration._adbMobileConnector, "mediaTrackPause")
  m.adobeIntegration.track(payload)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test Video Playback Resumed event
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure ADBMobile mediaTrackPlay gets invoked
'@Params[{"event": "Video Playback Resumed"}]
function SAIT__trackVideo_videoPlaybackResumed(payload) as void
  m.ExpectOnce(m.adobeIntegration._adbMobileConnector, "mediaTrackPlay")
  m.adobeIntegration.track(payload)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test Video Ad Started events
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure ADBMobile mediaTrackEvent gets invoked with correct ad payload
'@Params["MediaAdStart", {"messageId": "id", "event": "Video Ad Started", "context": {}, "properties": {"title":"n", "total_length":1.5, "asset_id":"a", "indexPosition": 2}}, {"position":2, "name":"n", "media_standard_content_metadata":{"a.media.format":"vod"}, "length":1.5, "id":"a"}, {"adb_id":"id"}]
function SAIT__trackVideo_videoAdStarted(event, payload, mediaObject, data) as void
  'Need to convert integer to roFloat in order for ExpectOnce() to work
  m.AssertEqual(type(mediaObject.position), "roInteger")
  initialPosition = str(mediaObject.position)
  position = createObject("roFloat")
  position.setFloat(initialPosition.toFloat())
  mediaObject.position = position

  m.Expect(m.adobeIntegration._adbMobileConnector, "mediaTrackEvent", 2, [event, mediaObject, data])
  m.adobeIntegration.track(payload)
end function


'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test Video Ad Skipped events
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure ADBMobile mediaTrackEvent gets invoked with correct ad skipped payload
'@Params["MediaAdSkip", {"messageId": "id", "event": "Video Ad Skipped", "context": {}, "properties": {"title":"n", "total_length":1.5, "asset_id":"a", "indexPosition": 2}}, {"position":2, "name":"n", "media_standard_content_metadata":{"a.media.format":"vod"}, "length":1.5, "id":"a"}, {"adb_id":"id"}]
function SAIT__trackVideo_videoAdSkipped(event, payload, mediaObject, data) as void
  'Need to convert integer to roFloat in order for ExpectOnce() to work
  m.AssertEqual(type(mediaObject.position), "roInteger")
  initialPosition = str(mediaObject.position)
  position = createObject("roFloat")
  position.setFloat(initialPosition.toFloat())
  mediaObject.position = position

  m.ExpectOnce(m.adobeIntegration._adbMobileConnector, "mediaTrackEvent", [event, mediaObject, data])
  m.adobeIntegration.track(payload)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test Video Ad Completed events
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure ADBMobile mediaTrackEvent gets invoked with correct event
'@Params["MediaAdBreakComplete", {"messageId": "id", "event": "Video Ad Completed", "context": {}, "properties": {"title":"n", "start_time":1.5, "asset_id":"a", "indexPosition": 2}}, {"position":2, "name":"n", "media_standard_content_metadata":{"a.media.format":"vod"}, "starttime":1.5}, {"adb_id":"id"}]
function SAIT__trackVideo_videoAdCompleted(event, payload, mediaObject, data) as void
  'Need to convert integer to roFloat in order for ExpectOnce() to work
  m.AssertEqual(type(mediaObject.position), "roInteger")
  initialPosition = str(mediaObject.position)
  position = createObject("roFloat")
  position.setFloat(initialPosition.toFloat())
  mediaObject.position = position

  m.Expect(m.adobeIntegration._adbMobileConnector, "mediaTrackEvent", 2, [event, mediaObject, data])
  m.adobeIntegration.track(payload)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test Video Playback Completed event
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure ADBMobile mediaTrackSessionEnd and mediaTrackComplete gets invoked
'@Params[{"event": "Video Playback Completed"}]
function SAIT__trackVideo_videoPlaybackCompleted(payload) as void
  m.ExpectOnce(m.adobeIntegration._adbMobileConnector, "mediaTrackComplete")
  m.ExpectOnce(m.adobeIntegration._adbMobileConnector, "mediaTrackSessionEnd")
  m.adobeIntegration.track(payload)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test Video Playback Exited event
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure ADBMobile mediaTrackPause and mediaTrackSessionEnd get invoked
'@Params[{"event": "Video Playback Exited"}]
function SAIT__trackVideo_videoPlaybackExited(payload) as void
  m.ExpectOnce(m.adobeIntegration._adbMobileConnector, "mediaTrackSessionEnd")
  m.adobeIntegration.track(payload)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test Video Content Started event
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure ADBMobile mediaTrackPlay and mediaTrackEvent gets invoked with correct payload
'@Params["MediaChapterStart", {"messageId": "id", "event": "Video Content Started", "context": {}, "properties": {"position": 1, "indexPosition": 2, "title":"n", "total_length":10.5, "start_time":1.8}}, {"position":2, "name":"n", "media_standard_content_metadata":{"a.media.format":"vod"}, "length":10.5, "offset":1.8}, {"adb_id":"id"}]
function SAIT__trackVideo_videoContentStarted(event, payload, mediaObject, data) as void
  'Need to convert roInteger to roFloat in order for ExpectOnce() to work
  m.AssertEqual(type(mediaObject.position), "roInteger")
  initialPosition = str(mediaObject.position)
  position = createObject("roFloat")
  position.setFloat(initialPosition.toFloat())
  mediaObject.position = position

  m.ExpectOnce(m.adobeIntegration._adbMobileConnector, "mediaTrackEvent", [event, mediaObject, data])
  m.ExpectOnce(m.adobeIntegration._adbMobileConnector, "mediaTrackPlay")
  m.adobeIntegration.track(payload)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test Video Content Completed event
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure ADBMobile mediaTrackEvent an get invoked with correct payload
'@Params["MediaChapterComplete", {"messageId": "id", "event": "Video Content Completed", "context": {}, "properties": {"position": 1, "indexPosition": 2, "title":"n", "total_length":10.5, "start_time":1.8}}, {"name":"n", "position":2, "media_standard_content_metadata":{"a.media.format":"vod"}, "length":10.5, "offset":1.8}, {"adb_id":"id"}]
function SAIT__trackVideo_videoContentCompleted(event, payload, mediaObject, data) as void
  'Need to convert roInteger to roFloat in order for ExpectOnce() to work
  m.AssertEqual(type(mediaObject.position), "roInteger")
  initialPosition = str(mediaObject.position)
  position = createObject("roFloat")
  position.setFloat(initialPosition.toFloat())
  mediaObject.position = position

  m.ExpectOnce(m.adobeIntegration._adbMobileConnector, "mediaTrackEvent", [event, mediaObject, data])
  m.adobeIntegration.track(payload)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test Video Playback Buffer/Seek Started/Completed events
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure ADBMobile mediaTrackEvent gets invoked with correct payload
'@Params["MediaBufferStart", {"messageId": "id", "event": "Video Playback Buffer Started", "context": {}, "properties": {"title":"n", "total_length":10.5, "content_asset_id":"a"}}, {"name":"n", "media_standard_content_metadata":{"a.media.format":"vod"}, "length":10.5, "mediatype":"video", "streamtype":"vod", "id":"a"}, {"adb_id":"id"}]
'@Params["MediaSeekStart", {"messageId": "id", "event": "Video Playback Seek Started", "context": {}, "properties": {"title":"n", "total_length":10.5, "content_asset_id":"a"}}, {"name":"n", "media_standard_content_metadata":{"a.media.format":"vod"}, "length":10.5, "mediatype":"video", "streamtype":"vod", "id":"a"}, {"adb_id":"id"}]
'@Params["MediaBufferComplete", {"messageId": "id", "event": "Video Playback Buffer Completed", "context": {}, "properties": {"title":"n", "total_length":10.5, "content_asset_id":"a"}}, {"name":"n", "media_standard_content_metadata":{"a.media.format":"vod"}, "length":10.5, "mediatype":"video", "streamtype":"vod", "id":"a"}, {"adb_id":"id"}]
'@Params["MediaSeekComplete", {"messageId": "id", "event": "Video Playback Seek Completed", "context": {}, "properties": {"title":"n", "total_length":10.5, "content_asset_id":"a"}}, {"name":"n", "media_standard_content_metadata":{"a.media.format":"vod"}, "length":10.5, "mediatype":"video", "streamtype":"vod", "id":"a"}, {"adb_id":"id"}]
function SAIT__trackVideo_videoPlaybackSeekOrBuffer(event, payload, mediaObject, data) as void
  m.ExpectOnce(m.adobeIntegration._adbMobileConnector, "mediaTrackEvent", [event, mediaObject, data])
  m.adobeIntegration.track(payload)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test Video Quality Updated event
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure ADBMobile mediaUpdateQoS gets invoked with correct payload
'@Params["MediaBitrateChange", {"event": "Video Quality Updated", properties: {"bitrate": 23000.4, "startup_time": 1.23, "fps": 24.9, "dropped_frames": 2.1}}, {"bitrate": 23000.4, "startuptime": 1.23, "fps": 24.9, "droppedframes": 2.1}]
function SAIT__trackVideo_videoQualityUpdated(event, payload, qos) as void
  m.ExpectOnce(m.adobeIntegration._adbMobileConnector, "mediaUpdateQoS", [qos])
  m.adobeIntegration.track(payload)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test mapStandardMetaData
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure meta data is correctly mapped
'@Params["Content", {"livestream": false, "program": "p", "season": "s", "episode": "e", "genre": "g", "channel": "c", "airdate": "d", "rating": "r", "publisher": "pub"}, {"a.media.airDate": "d", "a.media.episode": "e", "a.media.format": "vod", "a.media.genre": "g", "a.media.network": "c", "a.media.originator": "pub", "a.media.rating": "r", "a.media.season": "s", "a.media.show": "p"}]
'@Params["Content", {"livestream": false, "program": "p", "season": "s", "episode": "e", "genre": "g", "channel": "c", "airdate": "d", "rating": "r"}, {"a.media.airDate": "d", "a.media.episode": "e", "a.media.format": "vod", "a.media.genre": "g", "a.media.network": "c", "a.media.rating": "r", "a.media.season": "s", "a.media.show": "p"}]
'@Params["Content", {"livestream": true, "program": "p", "season": "s", "episode": "e", "genre": "g", "channel": "c", "airdate": "d", "rating": "r"}, {"a.media.airDate": "d", "a.media.episode": "e", "a.media.format": "live", "a.media.genre": "g", "a.media.network": "c", "a.media.rating": "r", "a.media.season": "s", "a.media.show": "p"}]
'@Params["Ad", {"livestream": false, "program": "p", "season": "s", "episode": "e", "genre": "g", "channel": "c", "airdate": "d", "rating": "r"}, {"a.media.airDate": "d", "a.media.episode": "e", "a.media.format": "vod", "a.media.genre": "g", "a.media.network": "c", "a.media.rating": "r", "a.media.season": "s", "a.media.show": "p"}]
'@Params["Ad", {"livestream": false, "program": "p", "season": "s", "episode": "e", "genre": "g", "channel": "c", "airdate": "d", "rating": "r", "publisher": "pub"}, {"a.media.airDate": "d", "a.media.episode": "e", "a.media.format": "vod", "a.media.genre": "g", "a.media.network": "c", "a.media.ad.advertiser": "pub", "a.media.rating": "r", "a.media.season": "s", "a.media.show": "p"}]
'@Params["Ad Break", {"livestream": false, "program": "p", "season": "s", "episode": "e", "genre": "g", "channel": "c", "airdate": "d", "rating": "r"}, {"a.media.airDate": "d", "a.media.episode": "e", "a.media.format": "vod", "a.media.genre": "g", "a.media.network": "c", "a.media.rating": "r", "a.media.season": "s", "a.media.show": "p"}]
'@Params["Ad Break", {"livestream": false, program": "p", "season": "s", "episode": "e", "genre": "g", "channel": "c", "airdate": "d", "rating": "r", "publisher": "pub"}, {"a.media.airDate": "d", "a.media.episode": "e", "a.media.format": "vod", "a.media.genre": "g", "a.media.network": "c", "a.media.ad.advertiser": "pub", "a.media.rating": "r", "a.media.season": "s", "a.media.show": "p"}]
'@Params["Playback", {"livestream": false, program": "p", "season": "s", "episode": "e", "genre": "g", "channel": "c", "airdate": "d", "rating": "r"}, {"a.media.airDate": "d", "a.media.episode": "e", "a.media.format": "vod", "a.media.genre": "g", "a.media.network": "c", "a.media.rating": "r", "a.media.season": "s", "a.media.show": "p"}]
function SAIT__mapStandardMetaData(eventType, properties, expected) as void
  metaData = m.adobeIntegration._mapStandardMetaData(eventType, properties)
  m.AssertEqual(metaData, expected)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test extractTrackTopLevelProps
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure it maps only predefined keys
'@Params[{}]
'@Params[{"messageId": "testMessage", "event": "testEvent", "anonymousId": "testId"}]
'@Params[{"other": "testProp", "messageId": "testMessage", "event": "testEvent", "anonymousId": "testId"}]
function SAIT__extractTrackTopLevelProps(payload) as void
  topLevelProps = m.adobeIntegration._extractTrackTopLevelProps(payload)
  m.AssertEqual(topLevelProps.count(), 3)
  m.AssertEqual(topLevelProps.messageId, payload.messageId)
  m.AssertEqual(topLevelProps.event, payload.event)
  m.AssertEqual(topLevelProps.anonymousId, payload.anonymousId)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test extractScreenTopLevelProps
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure it maps only predefined keys
'@Params[{}]
'@Params[{"messageId": "testMessage", "name": "testName", "anonymousId": "testId"}]
'@Params[{"other": "testProp", "messageId": "testMessage", "name": "testName", "anonymousId": "testId"}]
function SAIT__extractScreenTopLevelProps(payload) as void
  topLevelProps = m.adobeIntegration._extractScreenTopLevelProps(payload)
  m.AssertEqual(topLevelProps.count(), 3)
  m.AssertEqual(topLevelProps.messageId, payload.messageId)
  m.AssertEqual(topLevelProps.name, payload.name)
  m.AssertEqual(topLevelProps.anonymousId, payload.anonymousId)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test videoPlaybackQOS with valid data
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure it maps only predefined keys and set them to 0 if not defined
'@Params[null, {"bitrate": 0, "fps": 0, "droppedframes": 0, "startuptime": 0}]
'@Params[{}, {"bitrate": 0, "fps": 0, "droppedFrames": 0, "startupTime": 0}]
'@Params[{"bitrate": 50000, "fps": 24, "dropped_frames": 2, "startup_time": 1}, {"bitrate": 50000, "fps": 24, "droppedframes": 2, "startuptime": 1}]
'@Params[{"bitrate": 50000.1, "fps": 24.9, "dropped_frames": 2.1, "startup_time": 1.5, "other": "test"}, {"bitrate": 50000.1, "fps": 24.9, "droppedframes": 2.1, "startuptime": 1.5}]
function SAIT__videoPlaybackQOS_validData(properties, expected) as void
  qos = m.adobeIntegration._videoPlaybackQOS(properties)
  
  if properties = invalid then
    properties = {}
    m.AssertEqual(formatJson(qos), formatJson(expected))
  else
    if properties.bitrate <> invalid then
      m.AssertNotEqual(qos.bitrate, 0)
    end if
    if properties.fps <> invalid then
      m.AssertNotEqual(qos.fps, 0)
    end if
    if properties.dropped_frames <> invalid then
      m.AssertNotEqual(qos.droppedframes, 0)
    end if
    if properties.startup_time <> invalid then
      m.AssertNotEqual(qos.startuptime, 0)
    end if
  end if
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test videoPlaybackQOS with invalid data
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure it maps only predefined keys and set them to 0 if type is invalid
'@Params[{"bitrate": "1", "fps": "1", "dropped_frames": "1", "startup_time": "1"},{"bitrate": 0, "fps": 0, "droppedframes": 0, "startuptime": 0}]
function SAIT__videoPlaybackQOS_invalidData(properties, expected) as void
  qos = m.adobeIntegration._videoPlaybackQOS(properties)
  m.AssertEqual(formatJson(qos), formatJson(expected))
end function
