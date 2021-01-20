'@TestSuite [SAIPT] Segment Adobe Integration Playhead Tests

'@Setup
function SAIPT_setup() as void
  m.allowNonExistingMethodsOnMocks = false
end function

'@BeforeEach
function SAIPT_BeforeEach() as void
  clock = {
    time: 0
    wait: function(seconds)
        m.time = m.time + seconds
        return m.time
      end function
    totalSeconds: function()
        return m.time
      end function
  }

  m.playhead = _SegmentAdobeIntegration_PlaybackState(clock)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test valid initial constructor
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test basic constructor values
function SAIPT__constructor_basic_success_initial() as void
  m.AssertEqual(m.playhead._isPaused, true)
  m.AssertEqual(m.playhead._playheadPositionTime, 0)
  m.AssertEqual(m.playhead._playheadPosition, 0)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test startp playhead
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure playhead is unpaused, playhead position and current time is stored
function SAIPT__startPlayhead() as void
  'Wait 1s before starting playhead
  m.playhead._clock.wait(1)
  startTime = m.playhead._clock.totalSeconds()
  m.playhead.startPlayhead(1)

  'Wait 1s before checking time
  m.playhead._clock.wait(1)
    
  m.AssertEqual(strI(m.playhead._playheadPosition), strI(1))
  m.AssertEqual(m.playhead._isPaused, false)
  m.AssertEqual(strI(m.playhead._playheadPositionTime), strI(startTime))
  m.AssertEqual(strI(m.playhead.getCurrentPlaybackTime()), strI(2))
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test pause playhead
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure playhead is paused, playhead position is calculated and current time is stored
function SAIPT__pausePlayhead() as void
  m.playhead.startPlayhead(1)
  
  'Wait 1s before pausing playhead
  m.playhead._clock.wait(1)
  m.playhead.pausePlayhead()
  pauseTime = m.playhead._clock.totalSeconds()

  'Wait 1s before checking time
  m.playhead._clock.wait(1)
  
  m.AssertEqual(strI(m.playhead._playheadPosition), strI(2))
  m.AssertEqual(m.playhead._isPaused, true)
  m.AssertEqual(strI(m.playhead._playheadPositionTime), strI(pauseTime))
  m.AssertEqual(strI(m.playhead.getCurrentPlaybackTime()), strI(2))
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test unpause Playhead
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure playhead is resumed and current time is stored
function SAIPT__unpausePlayhead() as void
  m.playhead.startPlayhead(1)

  'Wait 1s before pausing playhead
  m.playhead._clock.wait(1)
  pauseTime = m.playhead._clock.totalSeconds()
  m.playhead.pausePlayhead()
  m.playhead.unpausePlayhead()

  'Wait another 1s before checking time
  m.playhead._clock.wait(1)
    
  m.AssertEqual(strI(m.playhead._playheadPosition), strI(2))
  m.AssertEqual(m.playhead._isPaused, false)
  m.AssertEqual(strI(m.playhead.getCurrentPlaybackTime()), strI(3))
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test update playhead
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure playhead is updated with a new position and current time is stored
function SAIPT__updatePlayhead() as void
  m.playhead.startPlayhead(1)

  'Wait 1s before pausing playhead
  m.playhead._clock.wait(1)
  updateTime = m.playhead._clock.totalSeconds()
  m.playhead.updatePlayheadPosition(5)
    
  m.AssertEqual(strI(m.playhead._playheadPosition), strI(5))
  m.AssertEqual(m.playhead._isPaused, false)
  m.AssertEqual(strI(m.playhead._playheadPositionTime), strI(updateTime))
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test getCurrentPlaybackTime when playing
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure returned playhead position is calculated when playing
function SAIPT__getCurrentPlaybackTime_playing() as void
  m.playhead.startPlayhead(0)
  m.playhead._clock.wait(1)

  calculatedPosition = m.playhead.getCurrentPlaybackTime()
  m.AssertEqual(strI(calculatedPosition), strI(1))
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test getCurrentPlaybackTime when paused
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure current playhead position is returned when paused
function SAIPT__getCurrentPlaybackTime_paused() as void
  m.playhead.startPlayhead(0)
  m.playhead._clock.wait(1)
  m.playhead.pausePlayhead()
  m.playhead._clock.wait(1)

  m.ExpectNone(m.playhead, "_calculateCurrentPlayheadPosition")
  position = m.playhead.getCurrentPlaybackTime()
  m.AssertEqual(strI(position), strI(1))
end function