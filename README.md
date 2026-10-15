# ION SDK for iOS
## Description
This is the official ION SDK for the iOS platform. It is distributed using Swift Package Manager.

## Minimum requirements
This SDK is available from iOS 15 and above.


## Description
This is the official ION SDK for the iOS platform. It is distributed using Swift Package Manager.

## Minimum requirements
This SDK is available from iOS 15 and above.

## Table of Contents
- [Setup and Configuration](#setup-and-configuration)
- [Quick Start](#quick-start)
- [Core Integration](#core-integration)
  - [IONLocationManager](#ionlocationmanager)
  - [IONLocationManagerDelegate](#ionlocationmanagerdelegate)
  - [What to Show the User](#what-to-show-the-user)
  - [Showing the Floor Plan](#showing-the-floor-plan)
- [ViPS Mode (AR Marker-Based Positioning)](#vips-mode-ar-marker-based-positioning)
- [Swift Streams Support](#swift-streams-support)
- [Privacy and Data](#privacy-and-data)
- [Troubleshooting](#troubleshooting)
- [Migrating from 1.3.x](#migrating-from-13x)
- [Models Reference](#models-reference)
  - [Geofence Models](#geofence-models)
  - [POI (Point of Interest) Models](#poi-point-of-interest-models)
  - [Positioning Models](#positioning-models)
  - [ViPS Models](#vips-models)
  - [Licensing Models](#licensing-models)
  - [Calibration Models](#calibration-models)
  - [Stream Event Models](#stream-event-models)
  - [Routing Models](#routing-models)

---

## Setup and Configuration

### Installation

**Swift Package Manager**: in Xcode, choose **File ▸ Add Package Dependencies…**, enter the package
URL and select **Up to Next Major Version**:

```
https://github.com/Hidonix-Industries/ION-SDK-iOS
```

Or, in a `Package.swift`, replacing `X.Y.Z` with the latest release:

```swift
dependencies: [
    .package(url: "https://github.com/Hidonix-Industries/ION-SDK-iOS", from: "X.Y.Z")
],
targets: [
    .target(name: "YourApp", dependencies: [.product(name: "ion_ios", package: "ION-SDK-iOS")])
]
```

**Manually**: download and unzip `ion_ios.xcframework` from the
[Releases page](https://github.com/Hidonix-Industries/ION-SDK-iOS/releases) and add it to your target.

To use the library, add the following import statement at the top of your Swift files:

```swift
import ion_ios
```

Before you start using the SDK, you must configure your Xcode project and the ION CMS.

### 1. CMS Configuration
When creating your license in the ION CMS, ensure that you correctly set the **Bundle Identifier** of your application. The API Key is generated as output once the license is successfully created with the matching bundle ID.

The license also enables a set of features (such as `arNavigation` and `arTurnByTurn`) that you can change from the CMS at any time, and that your app can read to enable functionality without a new release — see [License features](#license-features).

### 2. Xcode Project Configuration
Provide the generated API Key to your Xcode project:
1. Go to your project settings.
2. Select your App Target.
3. Go to the **Info** tab.
4. Add a new field named `ionSdkApiClientKey`.
5. Set the value of `ionSdkApiClientKey` to the API Key provided to you via the ION CMS.

### 3. Required Permissions (Info.plist)

Add the following keys to your app's `Info.plist` to request necessary permissions:

| Key | Description |
| :--- | :--- |
| `NSMotionUsageDescription` | Required for motion-based positioning and environment detection. |
| `NSLocationWhenInUseUsageDescription` | Required for iBeacon ranging and outdoor GPS. |
| `NSLocationAlwaysAndWhenInUseUsageDescription` | Required: the SDK requests it for iBeacon-related services. |
| `NSBluetoothAlwaysUsageDescription` | Required for iBeacon-related services. |
| `NSCameraUsageDescription` | Required only in [ViPS mode](#vips-mode-ar-marker-based-positioning). The `ARView` is presented by the app, so requesting the camera permission is the app's responsibility. |

The SDK **requests the location permissions itself** once it is started: *When In Use* for
positioning, and *Always* for iBeacon-related services. If you want to choose when the prompts
appear, request the permissions in your app before calling `start()`. Whatever the user answers,
[`PositioningAvailability`](#position-and-heading) tells you whether the SDK can position them.

---

## Quick Start

A minimal integration in standard mode: start the SDK while the screen is visible, show the floor
plan of the building and floor the user is on, and draw the position with the right state.

```swift
import CoreLocation
import UIKit
import ion_ios

final class MapViewController: UIViewController, @preconcurrency IONLocationManagerDelegate {
    private let locationManager = IONLocationManager()
    private var indoorPositionIsReliable = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        locationManager.delegate = self
        locationManager.start()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        locationManager.stop()
    }

    // 1. Whether the SDK can position the user at all.
    func indoorLocationManager(_ manager: IONLocationManagerProtocol, didUpdate availability: PositioningAvailability) {
        switch availability {
        case .unavailable(.locationPermissionDenied):     showMessage("Allow location access in Settings")
        case .unavailable(.locationPermissionRestricted): showMessage("Location access is restricted on this device")
        case .unavailable(.noLocationNearby):             showMessage("You are not near any venue")
        default:                                          showMessage(nil)
        }
    }

    // 2. Which floor plan to show.
    func indoorLocationManager(_ manager: IONLocationManagerProtocol, didEnterBuilding building: Building) {
        // Until didChangeFloor says otherwise, the user is on the ground level.
        if let groundLevel = building.levels.first(where: { $0.number == building.ground_level }) {
            showFloorPlan(groundLevel)
        }
    }

    func indoorLocationManager(_ manager: IONLocationManagerProtocol, didChangeFloor floor: Level) {
        showFloorPlan(floor)
    }

    // 3. Whether the indoor position can be trusted yet (outdoor GPS positions don't affect it).
    func indoorLocationManager(_ manager: IONLocationManagerProtocol, didUpdate reliability: IndoorPositionReliability) {
        indoorPositionIsReliable = reliability.isReliable
        showHint(reliability == .notReliable(.waitingForUserToWalk) ? "Walk a few steps to locate you" : nil)
    }

    // 4. Where the user is.
    func indoorLocationManager(_ manager: IONLocationManagerProtocol, didUpdate position: CLLocation, source: PositionSource) {
        showUserDot(at: position.coordinate,
                    onFloorPlan: source.isIndoor,
                    dimmed: source.isIndoor && !indoorPositionIsReliable)
    }
}
```

`showMessage`, `showHint`, `showFloorPlan` and `showUserDot` stand for your own UI code — see
[Showing the Floor Plan](#showing-the-floor-plan) for what `showFloorPlan` needs. Every other
callback has a default implementation, so you only add the ones you need.

The delegate callbacks are delivered on the **main thread**. In the Swift 6 language mode, declare
the conformance as `@preconcurrency IONLocationManagerDelegate`, as above, to adopt the protocol from
a main-actor type such as a view controller; in the Swift 5 mode it isn't needed.

---

## Core Integration

The primary entry point for interacting with the ION SDK is the `IONLocationManager`.

### IONLocationManager

The `IONLocationManager` provides methods to start/stop the location services and to fetch additional data like POIs and routes.

It conforms to `IONLocationManagerProtocol`, which is also the type the delegate callbacks receive as their first parameter: depend on the protocol in your code if you want to replace the manager with a test double.

#### Initialization
```swift
let locationManager = IONLocationManager()
locationManager.delegate = self
```

There is also an **alternative initializer** that starts the SDK in ViPS mode (AR-based
positioning), where the camera, anchored to markers installed in the building, becomes the main
source of the indoor position:
```swift
@MainActor
let locationManager = IONLocationManager(arView: arView)
```
Everything else works the same way in both modes — see
[ViPS Mode (AR Marker-Based Positioning)](#vips-mode-ar-marker-based-positioning).

Which of the two to use is up to the app. To be able to switch ViPS on and off from the CMS
without a new app release, tie the choice to the license's `arNavigation` feature — see
[License features](#license-features).

#### Starting and Stopping
- `start()`: Activates the location manager to begin receiving updates.
- `stop()`: Deactivates the location manager and stops all updates. Recommended when updates are no longer needed to save battery.

**What `start()` does first**: it checks the license, and reports the result through
`indoorLocationManager(_:licenseIsValid:)`. If the license is not valid — wrong API key, a Bundle
Identifier that doesn't match the one set in the CMS, or no network at that moment — the SDK doesn't
start and **no other callback arrives**: call `start()` again later (for example when the network is
back). Otherwise the session begins, and `IndoorPositionReliability` (`.notReliable(.waitingForIndoorPositioning)`)
and `PositioningAvailability` (`.determining`) are reported right away.

**Lifecycle**:
- Call `start()` once per session; to restart a running manager, call `stop()` first.
- After `stop()` no more callbacks arrive. The delegate stays set, and a later `start()` begins a new
  session from scratch, reporting the initial states again.

**Background positioning is not supported**: the SDK provides positions only while the app is in
the foreground.

#### Fetching Data
- `getFullStandardPoiDetail(poiID: Int) async -> FullStandardPoi?`: Retrieves detailed information for a specific POI.
- `getRoute(endPoint: Waypoint, waypoints: [Waypoint]?, accessibilityMode: Bool?) async -> Route?`: Computes a route from the current position to a destination.
- `getLevelInfo(levelId: Int) async -> LevelInfo?`: Retrieves the details of a level given its id (see `LevelInfo`). Returns `nil` if the manager has never been started, or if the level can't be retrieved.
- `getLocationSummaries() async -> [LocationSummary]`: Returns all the Locations assigned to the license (see `LocationSummary`). It doesn't need `start()`.
- `checkLicensing() async -> LicenseStatus`: Manually triggers a check for the SDK license validity. Returns `.valid(features:)` with the `SdkFeature` values the license grants (`poi`, `safety`, `wayfinding`, `arNavigation`, `arTurnByTurn`; only the last two are meant for the app, the others can be ignored), or `.invalid`. It doesn't need `start()`: it can be called on a manager that hasn't been started yet, for example to decide whether to start in ViPS mode — see [License features](#license-features).

#### License features

Besides being valid or not, a license enables a set of **features** (`SdkFeature`): `poi`,
`safety`, `wayfinding`, `arNavigation` and `arTurnByTurn`. They are managed in the ION CMS and can
be changed there at any time; `checkLicensing()` returns the ones enabled at the moment of the call.

Only `arNavigation` and `arTurnByTurn` are meant to be read by the app: `poi`, `safety` and
`wayfinding` can be ignored.

This lets you turn functionality of your app on and off from the CMS, without touching its code or
publishing a new release: check the feature at runtime and enable what depends on it. For example,
to start in ViPS mode only while `arNavigation` is enabled for the license:

```swift
import ARKit
import RealityKit
import ion_ios

@MainActor
func makeLocationManager(arView: ARView) async -> IONLocationManager {
    let standardManager = IONLocationManager()
    let license = await standardManager.checkLicensing()
    guard license.grants(.arNavigation), ARWorldTrackingConfiguration.isSupported else {
        return standardManager                 // standard mode
    }
    return IONLocationManager(arView: arView)  // ViPS mode
}
```

`.invalid` enables no features, so when the check fails (no network, for example) the code above
falls back to standard mode. Checking `ARWorldTrackingConfiguration.isSupported` too avoids choosing
ViPS mode on a device where it can't start. The same pattern applies to the other features — for
instance, enabling your app's AR turn-by-turn guidance only while `arTurnByTurn` is enabled.

Tying ViPS mode to `arNavigation` is a choice of the app, not a requirement of the SDK.

---

### IONLocationManagerDelegate

Implement the `IONLocationManagerDelegate` protocol to receive real-time updates from the SDK. All
the callbacks are delivered on the **main thread**, so they can update the UI directly (see the
[Quick Start](#quick-start) for adopting the protocol in the Swift 6 language mode).

#### Position and Heading
- `indoorLocationManager(_:didUpdate: CLLocation)`: Called when a new position update is available.
- `indoorLocationManager(_:didUpdate: Double)`: Called when a new heading (orientation) update is available. The heading is in **radians**, in `[0, 2π)`, measured clockwise from north.
- `indoorLocationManager(_:didUpdate indoorPositionReliability: IndoorPositionReliability)`: Called when the **indoor** position becomes usable — or stops being usable — reporting `.reliable` / `.notReliable(reason)`.
  - It is called with `.notReliable(.waitingForIndoorPositioning)` right after a successful `start()`, and then on every change.
  - **Why it matters**: right after start the SDK doesn't know yet where the user is inside the building, and in venues **without beacons** it can only find out — both the floor and the position — once the user **walks**. Until then the published indoor position may be stuck on a wrong point. Use `.reliable` as the moment from which the indoor position can be shown/used, and surface `.waitingForUserToWalk` to the user (e.g. *"walk a few steps to locate you"*).
  - **Indoor scope only**: outdoor GPS positions never change this state (each carries its own `horizontalAccuracy`, which is what an app judges it by). While the SDK is outdoor, or hasn't resolved a building and a level yet, the state is `.notReliable(.waitingForIndoorPositioning)`.
  - The SDK **keeps publishing positions** during the unreliable phase, so existing integrations are unaffected: hiding, greying out or freezing the dot is up to the app.
  - It can return to `.notReliable` later in the session whenever the SDK has to locate the user again from scratch (for example after a floor change or a building transition), or when the user leaves the indoor area.
- `indoorLocationManager(_:didUpdate positioningAvailability: PositioningAvailability)`: Called when the SDK finds out whether it can position the user at all, and whenever that changes — reporting `.determining` / `.available` / `.unavailable(reason)`.
  - It is called with `.determining` right after a successful `start()`, and then on every change. `.determining` means the SDK doesn't know yet: it is waiting for the answer to the location permission prompt, for the first location fix, or for the backend to say which Location the fix falls in. `.available` means it has found that Location.
  - **Why it matters**: when positioning can't start, the other callbacks just stay silent — no building, no floor, and an `IndoorPositionReliability` stuck on `.waitingForIndoorPositioning`. This is the callback that says why, and each reason asks something different of the user:

    | `PositioningUnavailableReason` | meaning | what to tell the user |
    |---|---|---|
    | `.locationPermissionDenied` | access to location denied for the app, or Location Services turned off for the whole device: without a location fix the SDK can't find out which Location the user is in | *"allow location access in Settings"* |
    | `.locationPermissionRestricted` | access to location restricted by parental controls or a device management profile: the user can't grant it | *"location access is restricted on this device"* |
    | `.noLocationNearby` | there is a location fix, but no Location of the license is near it (GPS positions keep arriving as `.gps`) | *"you are not near any venue"* |

  - **No restart needed**: the SDK keeps trying on its own. Access granted from Settings is picked up while the app is running (back to `.determining` until the Location is found), and a user who gets close to a venue receives `.available` together with `didEnterLocation`.
  - A request that fails (no network, a server error) is **not** a reason: it says nothing about where the user is, so the state doesn't change — it stays `.determining` if nothing is known yet — and the SDK asks again at the next location fix.

**Every method of `IONLocationManagerDelegate` has a default implementation**, so you only have to
implement the callbacks you actually use — adopting the protocol with an empty body compiles.

#### Position

- `indoorLocationManager(_:didUpdate: CLLocation, source: PositionSource)`: a new position, and
  where it comes from. **This is the position callback to implement.**

  | `PositionSource` | meaning |
  |---|---|
  | `.gps` | outdoor GPS; carries its own `horizontalAccuracy` and never affects `IndoorPositionReliability` |
  | `.filterAR` | indoor position **with ViPS contributing** — only reachable in ViPS mode |
  | `.filter` | indoor position, without ViPS |
  | `.deadReckoning` | indoor position carried forward from the user's movement, while the SDK can't locate the user directly |
  | `.outdoorDeadReckoning` | position carried forward from the user's movement between leaving a building's transition area and entering its indoor area, where neither GPS nor indoor positioning is available |

  `PositionSource.isIndoor` answers the question most apps ask of it (which map to show).

  It describes the SOURCE, not the quality: `IndoorPositionReliability` is the signal for whether
  the indoor position may be used, and the two are independent — a `.filter` position can
  be perfectly usable, and a `.filterAR` one can arrive while the reliability still asks
  for a marker.
- `indoorLocationManager(_:didUpdate: CLLocation)`: the same callback **without** the source, kept
  for integrations written before `PositionSource` existed. Nothing to change: the SDK calls the
  method above, whose default implementation forwards to this one. Implement one or the other — if
  you implement both, only the one with `source` is called.

#### ViPS
- `indoorLocationManager(_:didRecognizeARMarker: ARMarker)`: Called every time an AR marker is recognised and the position is anchored on it. Fires **only** when the manager was created with `init(arView:)`. It is the moment the position is at its most accurate: the marker's position on the floor plan is known, so the user's position is placed on it and any error accumulated since the previous marker is cleared. Called on every anchoring, including repeated sightings of the same marker — compare `ARMarker.id` if only the changes are of interest.

#### Location, Floor and Building Transitions
- `indoorLocationManager(_:didEnterLocation: Location)`: Notifies when the SDK finds the Location (site) the user is in — the same moment `PositioningAvailability` becomes `.available`.
- `indoorLocationManager(_:didChangeFloor: Level)`: Notifies when the user's floor level changes.
- `indoorLocationManager(_:didEnterBuilding: Building)`: Notifies when the user enters a building.
- `indoorLocationManager(_:didExitBuilding: Building)`: Notifies when the user exits a building.
- `indoorLocationManager(_:didEnterVenue: Building)`: Notifies when the user enters a venue.
- `indoorLocationManager(_:didExitVenue: Building)`: Notifies when the user exits a venue.

**The floor on entering a building**: when the SDK places the user on a specific floor it announces
it with `didChangeFloor`; when it doesn't, after `didEnterBuilding` the user is on the building's
ground level (the `Level` whose `number` is `Building.ground_level`) until a `didChangeFloor` says
otherwise. The exception is [ViPS mode](#vips-mode-ar-marker-based-positioning), where no floor is
announced until the first marker is recognised. `didEnterBuilding` can be called more than once for
the same building (for example on reaching the building's transition area and then its indoor
area): compare `Building.id` if only the changes are of interest.

#### Area and Geofence Events
- `indoorLocationManager(_:enteredIndoorArea: SystemGeofence)`: User entered an indoor area.
- `indoorLocationManager(_:enteredOutdoorArea: SystemGeofence)`: User entered an outdoor area.
- `indoorLocationManager(_:enteredMappedArea: SystemGeofence)`: User entered a mapped area.
- `indoorLocationManager(_:enteredNotMappedArea: SystemGeofence)`: User entered a non-mapped area.
- `indoorLocationManager(_:buildingTransitionGeofence:exitedBuilding:enteredBuilding:)`: Notifies when a building transition occurs across a geofence.
- `indoorLocationManager(_:triggeredIndoorGeofence:event:indoorGeofence:indoorGeofenceResponse:)`: Triggered when an security geofence event occurs (Security Geofences are: `Crowd Management Areas` and `Restricted Areas`)

#### Miscellaneous
- `indoorLocationManager(_:shouldCalibrate:calibrationLevel:percentage:)`: Notifies the state of the device geomagnetic sensor calibration, once per second while indoor positioning is active. `shouldCalibrate` is `true` when the user should be asked to perform the figure-of-eight movement (the reading has stayed poor for a while without recovering on its own, and the user is not already performing the gesture); `calibrationLevel` is a `MagCalibrationLevel` (`.good` / `.warning` / `.bad`) for colouring the UI; `percentage` is the quality of the magnetic reading, `0...100`.
- `indoorLocationManager(_:poisForFloor:fullStandardPois:servicePois:)`: Provides the list of POIs for the current floor. (**Note**: while the Level object already contains StandardPoi references, this method provides FullStandardPoi objects, which offer more comprehensive data).
- `indoorLocationManager(_:poisForLocation:standardPois:servicePois:)`: Provides the list of POIs for a specific location.
- `indoorLocationManager(_:licenseIsValid: Bool)`: Called by `start()` with the result of its license check. When `false`, the SDK doesn't start and no other callback arrives — see [Starting and Stopping](#starting-and-stopping). To read the license features, use `checkLicensing()` instead.

---

### What to Show the User

Four signals together decide what the app shows. Each answers a different question:

| Signal | Question it answers |
|---|---|
| `licenseIsValid` | Did the SDK start at all? |
| `PositioningAvailability` | Can the SDK position the user? |
| `PositionSource` (with each position) | Is the position indoor or outdoor, and where does it come from? |
| `IndoorPositionReliability` | Can the indoor position be trusted yet? |

| Situation | How you recognise it | Suggested UI |
|---|---|---|
| License not valid | `licenseIsValid(false)` | The SDK isn't running: check the configuration, retry `start()` later |
| Waiting | `PositioningAvailability.determining` | A neutral "locating…" state |
| Location access denied | `.unavailable(.locationPermissionDenied)` | Ask the user to allow location access in Settings |
| Location access restricted | `.unavailable(.locationPermissionRestricted)` | Explain that location access can't be enabled on this device |
| Not near a venue | `.unavailable(.noLocationNearby)` | "You are not near any venue"; GPS positions (`.gps`) keep arriving |
| Outdoor | `PositionSource.isIndoor == false` | The dot on your outdoor map, judged by its `horizontalAccuracy` |
| Indoor, still locating | `.notReliable(.waitingForIndoorPositioning)` or `.notReliable(.converging)` | The dot hidden or greyed out on the floor plan |
| Indoor, the user has to walk | `.notReliable(.waitingForUserToWalk)` | "Walk a few steps to locate you" |
| Indoor, usable | `IndoorPositionReliability.reliable` | The dot on the floor plan |
| ViPS, no marker yet | `.notReliable(.waitingForARMarker)` | "Point the camera at a marker" |
| ViPS lost | `.notReliable(.arReferenceLost)` | The dot greyed out, and "point the camera at a marker" |
| Compass needs calibrating | `shouldCalibrate == true` | Ask for the figure-of-eight movement |

The [Quick Start](#quick-start) shows these signals wired together.

---

### Showing the Floor Plan

The SDK doesn't draw anything: positions are standard `CLLocation` coordinates, so you can show them
with any map engine (es. MapBox, …). To show the floor plan under them, overlay the
plan's image on the map. Everything needed is in the `LevelMap` of the level,
`level.retrievedMap.map`:

- `map_floor_url`: URL of the floor plan image.
- `width` / `height`: the plan's size, in meters.
- `rotation`: the plan's orientation, in degrees, measured clockwise from geographic north to the
  plan's up direction.
- `georeference`: the reference points that place the plan on the globe (`[GeoCoordinate]`); the
  one at index 2 is the plan's bottom-left corner.

The `Level` objects delivered by the SDK (`didChangeFloor`, `Building.levels`) always carry their
map. For a building's outdoor map, the same data is in `Building.outdoorLevel` (`OutdoorLevel`).

---

## ViPS Mode (AR Marker-Based Positioning)

**ViPS** is the SDK's AR-based positioning technology. Besides the standard `IONLocationManager()`,
the SDK can be initialized in **ViPS mode** by handing over the `ARView` of the host app:

```swift
import RealityKit
import UIKit
import ion_ios

@MainActor
final class ARNavigationController: UIViewController, @preconcurrency IONLocationManagerDelegate {
    private let arView = ARView(frame: .zero)
    private lazy var locationManager = IONLocationManager(arView: arView)

    override func viewDidLoad() {
        super.viewDidLoad()
        // The view belongs to the app: layout, entities and rendering are yours.
        view.addSubview(arView)
        locationManager.delegate = self
        locationManager.start()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        locationManager.stop()   // also stops the AR session
    }

    func indoorLocationManager(_ manager: IONLocationManagerProtocol, didRecognizeARMarker marker: ARMarker) {
        // The position has just been anchored on marker.id, on level marker.floorId.
    }

    func indoorLocationManager(_ manager: IONLocationManagerProtocol, didUpdate reliability: IndoorPositionReliability) {
        switch reliability {
        case .notReliable(.waitingForARMarker):
            // ViPS hasn't started yet: ask the user to frame a marker.
            showMarkerHint()
        case .notReliable(.arReferenceLost):
            // ViPS was working and stopped: framing any marker recovers it immediately.
            showMarkerHint()
        default:
            hideMarkerHint()
        }
    }
}
```

In this mode the indoor position comes from the camera, anchored to the floor plan by printed
**image markers** whose position on the plan is configured in the CMS. ViPS works together with the
SDK's other indoor positioning sources rather than replacing them: while the camera tracks well,
ViPS alone determines the position; as its tracking degrades, the other sources gradually take over,
so the position degrades smoothly instead of disappearing.

### Requirements

- A device that supports world tracking (`ARWorldTrackingConfiguration.isSupported`); on any other
  device ViPS is not started.
- `NSCameraUsageDescription` in the app's `Info.plist`, and the camera permission granted: the
  `ARView` and its session are presented by the app, so the permission is the app's responsibility.
- At least one `ARMarker` configured for the building, on one of its levels.
- `init(arView:)` and `start()` / `stop()` are `@MainActor`.

### What the SDK does with your `ARView`

The SDK takes over the configuration of the view's `ARSession`: it turns
`automaticallyConfigureSession` off and runs the session with its own `ARWorldTrackingConfiguration`.
Don't run a different configuration on the same session: it would replace the SDK's and stop ViPS.

To save GPU time, some render options are disabled: camera grain, HDR, motion blur, depth of field,
face mesh, person occlusion, grounding shadows and AR environment lighting. Take this into account
if your app renders its own AR content in the view.

Everything else — the view's layout, its entities, its contents — is left to the app.

### Flow

1. **`start()`** — the SDK behaves exactly as in standard mode until a building is confirmed: outdoor
   GPS positioning, venue/building geofences, license check.
2. **Building confirmed** — the SDK downloads the building's markers and prepares them for
   recognition in the background. Markers that can't be used (broken image URL, non-positive
   `physicalWidth`, a `floorId` that doesn't belong to one of the building's levels) are skipped
   without affecting the others.
3. **Waiting for the first marker** — the AR session starts and the reliability state becomes
   `.notReliable(.waitingForARMarker)`. No indoor position is published at all in this phase, and no
   floor is announced: in ViPS mode the SDK doesn't guess the starting floor, because it would announce
   a floor it has no evidence for. Ask the user to point the camera at a marker.
4. **First marker recognised** — from this moment the SDK knows exactly where the user is:
   - the current floor becomes the marker's level, `marker.floorId`;
   - `didRecognizeARMarker` fires;
   - indoor positions start being published at ~4 Hz, starting exactly from the marker, with a
     `horizontalAccuracy` well under a metre while ViPS is tracking well.
   Heading updates work as in standard mode.
5. **Walking away from the markers** — ViPS keeps following the user through the camera alone. Its
   accuracy decreases slowly with the distance walked, and much faster when the camera can't track
   well (fast movements, poor lighting, the camera pointed at a blank surface or covered). As it
   decreases, the SDK's other indoor positioning sources gradually take over: there is no switch,
   and the position doesn't jump. Every later sighting of any marker places the position back on it
   and clears the accumulated error.
6. **ViPS lost** — once ViPS no longer contributes, the reliability state becomes
   `.notReliable(.arReferenceLost)`. Positions keep being published from the other sources, without
   jumps. Marker recognition keeps running, and the next marker the user frames hands the position
   back to ViPS.
7. **Floor changes without a marker** — ViPS tries to keep following the user onto the new floor. If
   camera tracking survived the floor change, the position stays usable throughout; if it didn't —
   the normal outcome in a lift — the state goes to `.arReferenceLost` and the other sources position
   the user on the new floor until a marker is framed there.
8. **`stop()`** — pauses the AR session and stops all updates, as in standard mode.

### Notes and limits

- **Enabling it from the CMS**: whether to start in ViPS mode is up to the app. Tying the choice to
  the license's `arNavigation` feature lets you switch ViPS on and off from the CMS — see
  [License features](#license-features).
- **Both APIs**: ViPS mode is available with the delegate and with the streams. `IONStreamService`
  has the same alternative initializer, `IONStreamService(arView:)`, and emits the recognised
  markers on `arMarkerValues` (see [Swift Streams Support](#swift-streams-support)).
- **A building with no markers** configured (or none usable) simply never starts ViPS: indoor
  positioning works as in standard mode. Be aware, though, that ViPS mode doesn't guess the starting
  floor even then, so in a building with neither markers nor beacons no floor gets resolved — use
  ViPS mode only in buildings that are actually equipped with markers.
- **Markers are what makes ViPS work**: only a marker starts ViPS, and only a marker brings it back
  after it has been lost. Both `.waitingForARMarker` and `.arReferenceLost` are states the user can
  fix personally by framing a marker, which is why they are worth surfacing.

---

## Swift Streams Support

For developers who prefer modern Swift concurrency, the SDK also provides all the core functionalities via **Swift Streams** (`AsyncStream`).

Instead of using a delegate, you can subscribe to various `AsyncStream` properties exposed by the `IONStreamProtocol`. This allows you to handle updates using `for await` loops:

- `positionValues`: Stream of `CLLocation` updates.
- `positionUpdateValues`: The same positions, each paired with the `PositionSource` that produced
  it. Subscribe to this one *or* to `positionValues`, not both — they are fed from the same update.
- `headingValues`: Stream of `Double` heading updates, in radians in `[0, 2π)`, clockwise from north.
- `indoorPositionReliabilityValues`: Stream of `IndoorPositionReliability` updates (whether the published indoor position may be used yet).
- `positioningAvailabilityValues`: Stream of `PositioningAvailability` updates (whether the SDK can position the user at all: access to location denied or restricted, no Location nearby).
- `locationValues`: Stream of `Location` updates, emitted when the SDK finds the Location the user is in (the stream counterpart of `didEnterLocation`).
- `floorValues`: Stream of `Level` updates.
- `arMarkerValues`: Stream of `ARMarker` recognitions. Only emits in ViPS mode.
- `calibrationValues`: Stream of `CalibrationEvent` calibration status.
- `buildingValues`: Stream of `BuildingEventEnum` building entry/exit events.
- `venueValues`: Stream of `VenueEventEnum` venue entry/exit events.
- `geofenceValues`: Stream of `GeofenceEvent` geofence triggers.
- `poiValues`: Stream of `PoiEvent` updates.
- `poiForLocationValues`: Stream of `PoiForLocationEvent` updates.
- `buildingTransitionGeofenceValues`: Stream of `BuildingTransitionGeofenceEvent` updates.
- `enteredNotMappedAreaValues`: Stream of `SystemGeofence` when entering a non-mapped area.
- `enteredMappedAreaValues`: Stream of `SystemGeofence` when entering a mapped area.
- `enteredOutdoorAreaValues`: Stream of `SystemGeofence` when entering an outdoor area.
- `enteredIndoorAreaValues`: Stream of `SystemGeofence` when entering an indoor area.

This stream-based approach provides the same robust functionality as the delegate pattern but in a more reactive and asynchronous style. The values the streams emit are described in [Stream Event Models](#stream-event-models).

Besides the streams, `IONStreamService` exposes the same methods as `IONLocationManager`: `start()` / `stop()`, `getFullStandardPoiDetail(poiID:)`, `getRoute(endPoint:waypoints:accessibilityMode:)`, `checkLicensing()`, `getLevelInfo(levelId:)` and `getLocationSummaries()`. The underlying manager is available as `ionObserver` (an `IONLocationManagerProtocol`), which is `nil` until `start()` is called.

**Subscribing to the streams**:
- **One subscriber per stream.** Each read of a stream property creates a new stream that replaces
  the previous one, which stops receiving values. Read each property once and share the values in
  your app if several parts of it need them.
- **Subscribe before `start()`**, so that the initial values (such as `.determining` and
  `.notReliable(.waitingForIndoorPositioning)`) aren't missed: read the stream properties first, then
  start. Values emitted before you iterate are buffered.
- **The streams don't finish on `stop()`**: to end a `for await` loop, cancel its `Task`.

### ViPS mode with the streams

`IONStreamService` has the same alternative initializer as `IONLocationManager`: pass the app's
`ARView` and `start()` builds the underlying manager in
[ViPS mode](#vips-mode-ar-marker-based-positioning). Every stream behaves as it does in standard mode, and
the recognised markers arrive on `arMarkerValues`. [License features](#license-features)
work the same way: `checkLicensing()` can be called on an `IONStreamService` that hasn't been
started yet.

```swift
@MainActor
let ion = IONStreamService(arView: arView)
let markers = ion.arMarkerValues
let reliabilities = ion.indoorPositionReliabilityValues
ion.start()

Task {
    for await marker in markers {
        // The position has just been anchored on marker.id, on level marker.floorId.
    }
}

Task {
    for await reliability in reliabilities {
        switch reliability {
        case .notReliable(.waitingForARMarker):
            // ViPS hasn't started yet: ask the user to frame a marker.
            showMarkerHint()
        case .notReliable(.arReferenceLost):
            // ViPS was working and stopped: framing any marker recovers it immediately.
            showMarkerHint()
        default:
            hideMarkerHint()
        }
    }
}
```

---

## Privacy and Data

What the SDK sends to the ION backend, so that you can describe it in your app's privacy disclosures
(for example the App Store privacy labels):

- **License check** (at every `start()`): the API key, the app's Bundle Identifier and an
  installation identifier — a random value generated by the SDK and stored on the device, reset when
  the app is reinstalled. Neither the advertising identifier nor `identifierForVendor` is used.
- **Location lookup**: the device's coordinates, to find which Location the user is in.
- **Position reports**: while the SDK is running and has a position, about once per second — the
  coordinates, heading, the floor, building and Location identifiers, the compass calibration state
  and a timestamp.
- **Security geofence events**: the identifier of the geofence and the event that occurred.
- **Content requests**: the identifiers of the Location, building, floor or POI being requested, and
  the start, destination and waypoints of a route.

The SDK ships with a privacy manifest (`PrivacyInfo.xcprivacy`) that declares precise location and a
device identifier as collected data, linked to the user and used for app functionality (location
also for analytics), and **no tracking**. Xcode includes it in your app's privacy report.

---

## Troubleshooting

- **No callback at all after `start()`, or `licenseIsValid(false)`**: the license check failed.
  Check that `ionSdkApiClientKey` in `Info.plist` is the key generated by the CMS, that the license's
  Bundle Identifier matches the app's, and that the device is online; then call `start()` again.
- **`PositioningAvailability` stays `.determining`**: the SDK is still waiting for the answer to the
  location permission prompt, for a location fix, or for the backend. Check the network and that the
  device can get a location fix.
- **`PositioningAvailability` is `.unavailable`**: see the reasons in
  [What to Show the User](#what-to-show-the-user).
- **The indoor dot sits on a wrong point**: check `IndoorPositionReliability`. Until it is
  `.reliable` the indoor position can't be trusted; with `.waitingForUserToWalk`, the user has to walk
  a few steps.
- **ViPS: no marker is ever recognised**: check that the camera permission is granted, that the
  device supports world tracking (`ARWorldTrackingConfiguration.isSupported`), that the building has
  markers configured in the CMS with the right `physicalWidth`, that your app doesn't run its own
  configuration on the `ARView`'s session, and that the marker is fully framed and well lit.
- **Swift 6 error "conformance … crosses into main actor-isolated code"**: declare the conformance as
  `@preconcurrency IONLocationManagerDelegate` — see the [Quick Start](#quick-start).
- **A stream stopped emitting**: its property was read again somewhere else, which replaces the
  previous subscription — see [Swift Streams Support](#swift-streams-support).
- **Some callbacks stopped arriving after updating from 1.3.x**: a few delegate methods were renamed
  — see [Migrating from 1.3.x](#migrating-from-13x).

---

## Models Reference

The following sections provide descriptions for the public models used across the ION SDK, grouped by their respective categories.

### Geofence Models

- **IndoorGeofence**: Represents a specific indoor geofence area. **Created as "Security Geofence" in the ION CMS.**
  - `id`: Unique identifier.
  - `title`: Title of the geofence.
  - `msg`: Message associated with the geofence trigger.
  - `triggerEvents`: List of `GeofenceTriggerEvent` that activate this geofence.
  - `dwellTime`: Time in seconds required for a dwell trigger.
  - `category`: The `GeofenceIndoorCategory` of the area.
  - `geofence`: List of `GeoCoordinate` defining the boundary.
- **SystemGeofence**: A specialized geofence used for system-level transitions. **Created as "System Area" in the ION CMS.**
  - `id`: Unique identifier.
  - `title`: Title of the geofence.
  - `msg`: Notification message.
  - `triggerEvents`: List of `GeofenceTriggerEvent`.
  - `dwellTime`: Dwell time in seconds.
  - `systemGeofenceType`: Type of transition (`SystemGeofenceType`).
  - `systemGeofenceUse`: Intended use (`SystemGeofenceUse`).
  - `triggerNotMappedBeacon`: UUID of the beacon triggering unmapped area entry.
  - `nextBuildingId` / `nextFloorId`: Target IDs for transitions.
  - `geofence`: Boundary coordinates.
  - `relatedGeofence`: Optional link to another `SystemGeofence`.
- **GeofenceTriggerEvent**: Defines the event type (`onEnter`, `onDwell`, or `onExit`).
  - `intValue`: Numeric code of the event: `onEnter` = 0, `onExit` = 1, `onDwell` = 2.
- **GeofenceIndoorCategory**: Categorizes indoor geofences.
  - Cases: `restricted` (value 0), `crowdManagement` (value 1).
- **IndoorGeofenceResponse**: Contains status info when a geofence trigger occurs.
  - `responseStatus`: Numerical status code.
  - `responseStatusName`: Human-readable status name.
  - `title` / `msg`: Response text.
- **SystemGeofenceType**: Specifies the system geofence type.
  - Cases: `notMapped`, `buildingTransition`, `indoorOutdoorTransition`.
- **SystemGeofenceUse**: Indicates the specific use-case.
  - Cases: `mapped`, `notMapped`, `indoorTransition`, `outdoorTransition`.

### POI (Point of Interest) Models

- **Poi** (protocol): The base protocol for all POI types, ensuring they have at least a unique identifier (`id`).
- **FullStandardPoi**: A comprehensive model for a standard POI.
  - `id`, `name`, `description`, `website`: Basic POI info.
  - `status`: Current status code.
  - `type` / `category`: Type and category codes.
  - `poiLocation`: Detailed address information (`PoiLocation`).
  - `webSocialLinks`: Social media profile links (`WebSocialLinks`).
  - `imageURLs`: List of URLs for POI images.
  - `hoursOfOperation`: Weekly schedule (`HourOfOperation`).
  - `latitude` / `longitude`: Physical coordinates.
  - `floorMapId` / `floorNumber`: Floor identification.
  - `buildingId` / `buildingName`: Building identification.
  - `typeValue` / `categoryValue` / `statusValue`: Human-readable strings for type, category, and status.

- **PoiLocation**: Detailed address data for a POI.
  - `address`, `addressDetails`, `city`, `country`, `zipCode`.
- **WebSocialLinks**: Social media links: `instagram`, `facebook`, `yelp`, `linkedIn`, `x`, `other`.
- **HourOfOperation**: Operational status for a specific day.
  - `daySlug`: String identifier for the day.
  - `isOpen`: Boolean status.
  - `timeSlots`: List of `TimeSlot` segments.
- **TimeSlot**: A time range (from/to).

- **StandardPoi**: A simplified version of a POI.
  - `id`, `name`: Basic POI info.
  - `latitude` / `longitude`: Physical coordinates.
  - `imageUrl`: Optional URL for the POI image.
  - `floorMapId` / `floorNumber`: Floor identification.
  - `buildingId` / `buildingName`: Building identification.
  - `typeValue` / `categoryValue`: Human-readable names.
- **ServicePoi**: A point of interest that provides specific services.
  - `id`, `name`: Basic POI info.
  - `latitude` / `longitude`: Physical coordinates.
  - `imageUrl`: Optional URL for the POI image.
  - `floorMapId` / `floorNumber`: Floor identification.
  - `buildingId` / `buildingName`: Building identification.
  - `typeValue` / `categoryValue`: Human-readable names.
- **PoiCategory**: Hierarchy of POI types and items.
  - `type`: The main classification (`PoiCategoryType`).
  - `categories`: List of sub-categories (`PoiCategoryItem`).
- **PoiCategoryType** / **PoiCategoryItem**: Contains `name` (String) and `value` (Int) for classification.
- **PoiStatus**: Represents a POI's operational status.
  - `name`: Human-readable status name.
  - `value`: Status code.

### Positioning Models

The positioning models follow a hierarchical structure, from the overall site location down to the individual sensors (beacons).

- **Location**: The top-level model representing a site.
  - `name`: Name of the site.
  - `id`: Unique identifier.
  - `coordinate`: Geographical center (`GeoCoordinate`).
  - `geofence_radius`: The radius in meters used for geographical geofencing triggers.
  - `light_buildings`: A list of `LightBuilding` objects belonging to this location.

- **LocationSummary**: A summary of one of the Locations assigned to the license, as returned by `getLocationSummaries()`.
  - `id`, `name`, `address`: Basic Location info.
  - `coordinate`: Geographical position (`GeoCoordinate`).
  - `imageUrl` / `thumbnailUrl`: URLs of the Location's image and of its thumbnail.
  - `creationDate` / `lastUpdate`: Optional dates of creation and of the last update, as strings.

- **LightBuilding**: A lightweight model representing a building within a location.
  - `name`: Name of the building.
  - `id`: Unique identifier.
  - `beacons_base_uuids`: A list of base UUIDs for all Bluetooth beacons belonging to this structure.
  - `address`: The physical mailing address of the building.
  - `ota`: Boundary of the building's outdoor transition area (`[GeoCoordinate]`).
  - `dict_major_beacons`: Optional map from a beacon's `major` value (as a string) to the id of the level the beacon is on.

- **Building**: Represents a full physical structure within a location.
  - `name`: Name of the building.
  - `id`: Unique identifier.
  - `address`: Physical address.
  - `beacons_base_uuids`: List of base UUIDs for beacons in this building.
  - `ground_level`: The floor number designated as ground level.
  - `levels`: Array of `Level` objects representing the floors.
  - `outdoorLevel`: Optional `OutdoorLevel`: the outdoor map around the building.
  - `ota`: Boundary of the building's outdoor transition area (`[GeoCoordinate]`).
  - `ia`: Boundary of the building's indoor area (`[GeoCoordinate]`).

- **Level**: Represents a specific floor within a building.
  - `name`: Display name of the floor.
  - `number`: Floor index (e.g., 0 for ground floor).
  - `id`: Unique identifier of the level.
  - `mapName`: Internal name of the map.
  - `height`: Altitude of the floor in meters.
  - `standardPois` / `servicePois`: Lists of POIs available on this floor.
  - `indoor_geofences` / `system_geofences`: Optional lists of geofences associated with the floor.
  - `mapLastUpdate`: Timestamp of the last map update.
  - `retrievedMap`: A `NavigationMap` containing the detailed map data.

- **LevelInfo**: The details of a level, as returned by `getLevelInfo(levelId:)`.
  - `id`: Identifier of the level — the same as `Level.id`.
  - `name` / `number`: Optional display name and floor index.
  - `buildingId` / `buildingName`: The building the level belongs to (`buildingName` is optional).
  - `imageUrl`: Optional URL of the level's image.
  - `georeference`: Optional reference points for alignment (`[GeoCoordinate]`), as in `LevelMap`.
  - `rotation`: Map rotation relative to geographical north, as in `LevelMap`.

- **NavigationMap**: A wrapper for map-related data.
  - `map`: A `LevelMap` object containing the floorplan and positioning details.

- **LevelMap**: Contains technical specifications for a floor's positioning.
  - `map_floor_url`: URL of the floorplan image.
  - `width` / `height`: Dimensions of the map in meters.
  - `rotation`: Map orientation, in degrees, measured clockwise from geographic north to the plan's up direction.
  - `georeference`: Reference points that place the plan on the globe (`[GeoCoordinate]`); the one at index 2 is the plan's bottom-left corner. See [Showing the Floor Plan](#showing-the-floor-plan).
  - `beacons`: List of `Beacon` objects deployed on this floor.

- **OutdoorLevel**: The outdoor map around a building (`Building.outdoorLevel`).
  - `id`: Unique identifier.
  - `floorplan`: The outdoor map image.
  - `width` / `height`: Dimensions of the map in meters.
  - `rotation`: Map rotation relative to geographical north.
  - `georeference`: Reference points for alignment (`[GeoCoordinate]`).

- **Beacon**: A Bluetooth beacon installed in the building for indoor positioning. Its identifiers are not part of the public API.

- **GeoCoordinate**: A basic structure for geographical positioning. Created with `GeoCoordinate(lat:lng:)`, for example to build a `Waypoint`.
  - `lat`: Latitude.
  - `lng`: Longitude.

- **IndoorPositionReliability**: Whether the indoor position currently published by the SDK may be used. Describes indoor positions only; outdoor GPS positions don't affect it.
  - `reliable`: From this moment on the indoor position can be used.
  - `notReliable(IndoorPositionUnreliableReason)`: The indoor position must not be trusted yet.
  - `isReliable`: Convenience `Bool` for the common check.

- **IndoorPositionUnreliableReason**: Why the published indoor position is not usable yet.
  - `waitingForIndoorPositioning`: Indoor positioning isn't producing a position at all — the SDK has just started, the user is outdoor (or in a building's transition area), or no building has been resolved yet. Any position published in this state is a GPS position or one carried forward from the user's movement (`.gps`, `.deadReckoning`, `.outdoorDeadReckoning`). If it lasts because positioning can't start at all (access to location denied, no Location nearby), `PositioningAvailability` says why.
  - `waitingForUserToWalk`: The SDK needs the user to walk in order to locate them, and no beacon is available to do it without walking. Reported both while the **floor** is being determined and while the **position** is. **This is the reason to surface to the user.**
  - `converging`: The SDK has what it needs; the indoor position is still settling.
  - `waitingForARMarker`: The SDK is running in [ViPS mode](#vips-mode-ar-marker-based-positioning) and no marker has been framed yet. **No indoor position is published at all while this is the reported reason**, since ViPS knows nothing about where the user is until the camera sees a marker. **This is the reason to surface to the user.**
  - `arReferenceLost`: ViPS was positioning the user and stopped — the user walked too far from the last marker or the camera could no longer track well, or the floor changed without a marker — so the position now comes from the SDK's other indoor sources, which are less precise and need a few seconds to settle. Distinct from `waitingForARMarker` on purpose: that one means ViPS never started in this session, this one that it was working and stopped. Both are resolved immediately by framing any of the building's markers.

- **PositioningAvailability**: Whether the SDK is able to position the user at all. A different question from `IndoorPositionReliability`, which judges a position the SDK is producing: this one says whether it can produce one in the first place.
  - `determining`: Not known yet — waiting for the answer to the location permission prompt, for the first location fix, or for the backend's answer about which Location the fix falls in. Also where it stays while those requests fail.
  - `available`: The SDK has access to location and has found the Location the user is in: positioning is under way.
  - `unavailable(PositioningUnavailableReason)`: The SDK cannot position the user.
  - `isAvailable`: Convenience `Bool` for the common check.

- **PositioningUnavailableReason**: Why the SDK cannot position the user.
  - `locationPermissionDenied`: Access to location denied for the app, or Location Services turned off for the whole device (CoreLocation reports both the same way). The user resolves it in Settings, and the SDK picks it up while running.
  - `locationPermissionRestricted`: Access to location restricted by parental controls or a device management profile — the user can't grant it.
  - `noLocationNearby`: The SDK has a location fix, but no Location of the license is near it. Not final: the SDK keeps asking as new fixes arrive.

- **PositionSource**: Where a published position comes from — see the table in [Position](#position).
  - `isIndoor`: Whether the position is a point on an indoor floor plan (`.filterAR`, `.filter`, `.deadReckoning`) rather than an outdoor one (`.gps`, `.outdoorDeadReckoning`) — usually what decides which map the app shows.

- **PositionUpdate**: The element of the `positionUpdateValues` stream: a position together with where it comes from.
  - `position`: The position (`CLLocation`).
  - `source`: Its `PositionSource`.

### ViPS Models

Only used in [ViPS mode](#vips-mode-ar-marker-based-positioning).

- **ARMarker**: A physical image installed in a building, used by ViPS as a reference point. Recognising one tells the SDK exactly where the device is, because the marker's position and orientation on the floor plan (`x`, `y`, `heading`) are known. Delivered to the app through `indoorLocationManager(_:didRecognizeARMarker:)` on every recognition.
  - `id`: Backend identifier of the marker.
  - `imageUrl`: URL of the marker artwork, which the SDK downloads in order to recognise the marker.
  - `physicalWidth`: Width of the **printed** marker, in meters. The SDK needs it to measure the distance to the marker; a non-positive value makes the marker unusable and it is skipped.
  - `x` / `y`: Position on the level map, in meters, **origin bottom-left with y growing upwards**. A marker authored in the top-left/y-down convention produces a position that is right along x and mirrored along y.
  - `heading`: Orientation of the marker on the level map: the standard mathematical angle, measured **counterclockwise from the map's +x axis**, in `(-π, π]`. So `0` faces +x (right on the plan), `π/2` faces +y (up), `±π` left, `-π/2` down. The angle describes the direction the marker **faces** (the normal coming out of its printed surface), not the direction of one of its edges.
  - `floorId`: Identifier of the level the marker is installed on — the same id as `Level.id`.

### Licensing Models

- **LicenseStatus**: The result of `checkLicensing()`.
  - `valid(features: [SdkFeature])`: The license is valid and enables these features. A valid license with no features is a legitimate answer, distinct from `invalid`.
  - `invalid`: The license could not be validated: no API key, no network, or the backend rejected it.
  - `isValid`: Convenience `Bool` for the common check.
  - `features`: The enabled features; empty when the license is not valid.
  - `grants(_:)`: Whether the license enables a specific feature.

- **SdkFeature**: A feature a license may enable, managed from the ION CMS — see [License features](#license-features).
  - `arNavigation`: AR navigation, i.e. [ViPS mode](#vips-mode-ar-marker-based-positioning).
  - `arTurnByTurn`: AR turn-by-turn guidance, on top of AR navigation.
  - `poi`, `safety`, `wayfinding`: Can be ignored.

### Calibration Models

The SDK evaluates the quality of the device's magnetic sensor reading by itself: the app only has to show it and, when asked, prompt the user to calibrate.

- **MagCalibrationLevel**: The quality of one reading as one of three levels, for colouring the UI. `Comparable`, ordered from best to worst, so several readings collapse with `max` and the worst one wins.
  - `.good`: percentage is 100. Draw green.
  - `.warning`: percentage from 70 to 99. Draw orange.
  - `.bad`: percentage below 70, which also covers an anomalous field and a sensor that declares itself unreliable. Draw red.

- **CalibrationEvent**: The value emitted by the `calibrationValues` stream, i.e. the same three parameters delivered by the delegate callback.
  - `shouldCalibrate`: Whether the user should be asked to perform the figure-of-eight movement.
  - `calibrationLevel`: The `MagCalibrationLevel` of the reading.
  - `percentage`: The quality of the magnetic reading, `0...100`.

### Stream Event Models

The values emitted by the [streams](#swift-streams-support) that carry several parameters of a delegate callback at once. `PositionUpdate` and `CalibrationEvent` are described with the positioning and calibration models.

- **BuildingEventEnum**: Emitted by `buildingValues`: `enter(Building)` / `exit(Building)`, the counterparts of `didEnterBuilding` / `didExitBuilding`.
- **VenueEventEnum**: Emitted by `venueValues`: `enter(Building)` / `exit(Building)`, the counterparts of `didEnterVenue` / `didExitVenue`.
- **GeofenceEvent**: Emitted by `geofenceValues`, the counterpart of `triggeredIndoorGeofence`.
  - `triggeredIndoorGeofenceEvent`: The `GeofenceTriggerEvent` that occurred.
  - `indoorGeofence`: The `IndoorGeofence` it occurred on.
  - `indoorGeofenceResponse`: Optional `IndoorGeofenceResponse`.
- **BuildingTransitionGeofenceEvent**: Emitted by `buildingTransitionGeofenceValues`, the counterpart of `buildingTransitionGeofence`.
  - `systemGeofence`: The `SystemGeofence` crossed.
  - `exitedBuilding` / `enteredBuilding`: The `Building` left and the one entered.
- **PoiEvent**: Emitted by `poiValues`, the counterpart of `poisForFloor`.
  - `level`: The `Level` the POIs belong to.
  - `fullStandardPois`: The floor's `FullStandardPoi` list.
  - `servicePoi`: The floor's `ServicePoi` list (an array, despite the singular name).
- **PoiForLocationEvent**: Emitted by `poiForLocationValues`, the counterpart of `poisForLocation`.
  - `location`: The `Location` the POIs belong to.
  - `standardPois` / `servicePois`: The Location's `StandardPoi` and `ServicePoi` lists.

### Routing Models

- **Route**: Represents a computed path following a GeoJSON-like structure.
  - `type`: The type of the route collection.
  - `features`: An array of `Feature` objects, each representing a segment of the route.
  - `meta`: Metadata about the entire route.
- **Feature**: A segment of a route.
  - `type`: The type of the feature.
  - `geometry`: The geographical shape of the segment (`Geometry`).
  - `properties`: Custom attributes for the segment (`Properties`).
- **Geometry**: The spatial component of a route segment.
  - `type`: The geometry type (e.g., "LineString" or "Point").
  - `coordinates`: Geographical coordinates, as a `CoordinatesEnum`.
- **Properties**: Navigation attributes for a route segment.
  - `instructionType`: The type of navigation instruction (`NavInstructionType`).
  - `instruction`: Human-readable navigation instruction.
  - `distanceMeters`: Optional length of the segment in meters.
  - `floorMapId`: ID of the floor map where this segment is located.
  - `floorFrom` / `floorTo`: Optional floor names for transitions.
  - `connectorSubType`: Optional type of transition connector (`ConnectorSubType`).
  - `waypointIndex`: Optional index of the associated waypoint.

#### Routing Enums

- **CoordinatesEnum**: The coordinates of a `Geometry`.
  - `point([Double])`: A single coordinate pair, for Points.
  - `lineString([[Double]])`: A list of coordinate pairs, for LineStrings.
- **NavInstructionType**: Defines navigation actions: `walk`, `turnLeft`, `turnRight`, `takeElevator`, `takeStairs`, `takeEscalator`, `takeRamp`, `takeCrossBuilding`, `arrive`, `waypoint`.
- **ConnectorSubType**: Defines connection types between floors: `stairs`, `elevator`, `escalator`, `ramp`, `crossBuilding`.
- **Meta**: Summary information for the route.
  - `estimatedTimeSeconds`: Total estimated time.
  - `totalDistanceMeters`: Total distance.
  - `floorChanges`: Number of floor changes.
  - `floorMapIds`: List of all floor map IDs involved.

- **Waypoint**: Represents a point on a route. Created with `Waypoint(coordinate:floorId:)`, for example as the `endPoint` of `getRoute`.
  - `coordinate`: Geographical position (`GeoCoordinate`).
  - `floorId`: Unique identifier of the level.
