# ION SDK for iOS
## Description
This is the official ION SDK for the iOS platform. It is distributed using Swift Package Manager.

## Minimum requirements
This SDK is available from iOS 15 and above.

## How to use it
1. Add the latest release as SPM dependency to your XCode project or download and unzip the .xcframework file from the Releases page.
2. Add your generated <api-key> string to the project Info.Plist using the key: ionSdkApiClientKey
3. In a project file of your interest add: import ion_ios
4. Chose the ION manager of your choice between: IONLocationManager (with delegate methods support) or IONStreamService (with AsyncStream support)
5. Rembember to call start() and stop() before and after using you library

## Available features
- Position and heading updates
- Floor enter/exit detection
- Building enter/exit detection
- Venue enter/exit detection
- Geofence event detection
- Poi fetching (via delegate method and on-demand)

