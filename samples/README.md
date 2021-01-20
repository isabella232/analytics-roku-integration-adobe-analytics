## Example

### Running the sample app

- Include `ADBMobileConfig.json` in the samples's root directory. See [Adobe's Docs](https://experienceleague.adobe.com/docs/media-analytics/using/sdk-implement/setup/set-up-roku.html?lang=en#sdk-implementation) for more details
- Set up `ROKU_DEV_TARGET` and `ROKU_DEV_PASSWORD` to the IP address and the development password of your Roku device
- Set the `SEGMENT_WRITE_KEY` environment variable to your Segment source write key
- Run `make install-app` from within the _samples/_ folder, which will build the app, side load it onto your Roku device and start it
