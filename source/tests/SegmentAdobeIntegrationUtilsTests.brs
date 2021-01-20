'@TestSuite [SAIUT] Segment Adobe Integration Utility Tests

'@Setup
function SAIUT_setup() as void
  m.allowNonExistingMethodsOnMocks = false
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test isInt
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure it only returns true if an integer
'@Params[1, true]
'@Params[0, true]
'@Params[null, false]
'@Params["", false]
'@Params[{}, false]
'@Params[true, false]
function SAIUT__isInt(value, expected) as void
  m.AssertEqual(_SegmentAdobeIntegration_isInt(value), expected)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test isFloat
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure it only returns true if a floating point number
'@Params[1.1, true]
'@Params[0.1, true]
'@Params[0, false]
'@Params[null, false]
'@Params["", false]
'@Params[{}, false]
'@Params[true, false]
function SAIUT__isFloat(value, expected) as void
  m.AssertEqual(_SegmentAdobeIntegration_isFloat(value), expected)
end function

'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
'@It test isString
'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

'@Test ensure it only returns true if a string
'@Params[1.1, false]
'@Params[0.1, false]
'@Params[0, false]
'@Params[null, false]
'@Params["", true]
'@Params[{}, false]
'@Params[true, false]
function SAIUT__isString(value, expected) as void
  m.AssertEqual(_SegmentAdobeIntegration_isString(value), expected)
end function