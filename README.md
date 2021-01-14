# Segment-Adobe-Analytics

## Example

### Running the sample app

- Include `ADBMobileConfig.json` in the samples's root directory. See [Adobe's Docs](https://experienceleague.adobe.com/docs/media-analytics/using/sdk-implement/setup/set-up-roku.html?lang=en#sdk-implementation) for more details
- Set up `ROKU_DEV_TARGET` and `ROKU_DEV_PASSWORD` to the IP address and the development password of your Roku device
- Set the `SEGMENT_WRITE_KEY` environment variable to your Segment source write key
- Run `make install-app` from within the _samples/_ folder, which will build the app, side load it onto your Roku device and start it

## Installation

Download the Segment and Adobe SDKs:

- [Segment SDK v2.0.0](https://github.com/segmentio/analytics-roku)
- [Adobe SDK v2.2.3](https://experienceleague.adobe.com/docs/media-analytics/using/sdk-implement/download-sdks.html?lang=en#download-3x-sdks)

Create **SegmentAdobeAnalytics.zip** with the required files:

```
make library
```

Import the SDK Libraries and the contents of **SegmentAdobeAnalytics.zip**:

```
|-- ADBMobileConfig.json
|-- components
|   |-- library
|   |   |-- Adobe Analytics SDK
|   |   |   |-- adbmobileTask.brs
|   |   |   |-- adbmobileTask.xml
|   |   |-- Segment SDK
|   |   |   |-- SegmentAnalyticsTask.brs
|   |   |   |-- SegmentAnalyticsTask.xml
|-- source
|   |-- library
|   |   |-- Adobe Analytics SDK
|   |   |   |-- adbmobile.brs
|   |   |-- Segment SDK
|   |   |   |-- SegmentAdobeIntegration.brs
|   |   |   |-- SegmentAnalytics.brs
|   |   |   |-- SegmentAnalyticsConnector.brs
```

Update file paths and make sure to include SegmentAdobeIntegrationFactory in the **use()** function:

```
<!-- samples/components/library/Adobe Analytics SDK/adbmobileTask.xml -->

<!-- Replace with correct location if needed -->
<script type="text/brightscript" uri="pkg:/components/library/Adobe Analytics SDK/adbmobileTask.brs"/>
<!-- Replace with correct location if needed -->
<script type="text/brightscript" uri="pkg:/source/library/Adobe Analytics SDK/adbmobile.brs"/>
```

```
<!-- samples/components/library/Segment SDK/SegmentAnalyticsTask.xml -->

<script type = "text/brightscript" >
  <![CDATA[

    function use() as Object
      return {
        "Adobe Analytics": SegmentAdobeIntegrationFactory
      }
    end function
  ]]>
</script>

<!-- include any device mode integrations scripts  -->
<script type="text/brightscript" uri="pkg:/source/library/Segment SDK/SegmentAdobeIntegration.brs" />
<script type="text/brightscript" uri="pkg:/source/library/Adobe Analytics SDK/adbmobile.brs"/>
```

Note: The Adobe integration will use **tmp:/ADBMobileConfig.json** if it exists. Otherwise, it will read **pkg:/ADBMobileConfig.json** and write it to **tmp:/ADBMobileConfig.json**.

## License

Segment-Adobe-Analytics is available under the MIT license. See the LICENSE file for more info.
