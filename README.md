# ION SDK for iOS
## Description
This is the official ION SDK for the iOS platform. It is distributed using Swift Package Manager.

## Minimum requirements
This SDK is available from iOS 15 and above.


## Table of Contents
- [Setup and Configuration](#setup-and-configuration)
- [Core Integration](#core-integration)
  - [IONLocationManager](#ionlocationmanager)
  - [IONLocationManagerDelegate](#ionlocationmanagerdelegate)
- [Swift Streams Support](#swift-streams-support)
- [Models Reference](#models-reference)
  - [Geofence Models](#geofence-models)
  - [POI (Point of Interest) Models](#poi-point-of-interest-models)
  - [Positioning Models](#positioning-models)
  - [Routing Models](#routing-models)

---

## Setup and Configuration

Add the latest release as SPM dependency to your XCode project or download and unzip the .xcframework file from the Releases page.

To use the library, add the following import statement at the top of your Swift files:

```swift
import ion_ios
```

Before you start using the SDK, you must configure your Xcode project and the ION CMS.

### 1. CMS Configuration
When creating your license in the ION CMS, ensure that you correctly set the **Bundle Identifier** of your application. The API Key is generated as output once the license is successfully created with the matching bundle ID.

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
| `NSLocationAlwaysAndWhenInUseUsageDescription` | Required for background updates and proximity features. |
| `NSBluetoothAlwaysUsageDescription` | Required for iBeacon-related services. |

---

## Core Integration

The primary entry point for interacting with the ION SDK is the `IONLocationManager`.

### IONLocationManager

The `IONLocationManager` provides methods to start/stop the location services and to fetch additional data like POIs and routes.

#### Initialization
```swift
let locationManager = IONLocationManager()
locationManager.delegate = self
```

#### Starting and Stopping
- `start()`: Activates the location manager to begin receiving updates.
- `stop()`: Deactivates the location manager and stops all updates. Recommended when updates are no longer needed to save battery.

#### Fetching Data
- `getFullStandardPoiDetail(poiID: Int) async -> FullStandardPoi?`: Retrieves detailed information for a specific POI.
- `getRoute(endPoint: Waypoint, waypoints: [Waypoint]?, accessibilityMode: Bool?) async -> Route?`: Computes a route from the current position to a destination.
- `checkLicensing() async -> Bool`: Manually triggers a check for the SDK license validity.

---

### IONLocationManagerDelegate

Implement the `IONLocationManagerDelegate` protocol to receive real-time updates from the SDK.

#### Position and Heading
- `indoorLocationManager(_:didUpdate: CLLocation)`: Called when a new position update is available.
- `indoorLocationManager(_:didUpdate: Double)`: Called when a new heading (orientation) update is available.

#### Floor and Building Transitions
- `indoorLocationManager(_:didChangeFloor: Level)`: Notifies when the user's floor level changes.
- `indoorLocationManager(_:didEnterBuilding: Building)`: Notifies when the user enters a building.
- `indoorLocationManager(_:didExitBuilding: Building)`: Notifies when the user exits a building.
- `indoorLocationManager(_:didEnterVenue: Building)`: Notifies when the user enters a venue.
- `indoorLocationManager(_:didExitVenue: Building)`: Notifies when the user exits a venue.

#### Area and Geofence Events
- `indoorLocationManager(_:enteredIndoorArea: SystemGeofence)`: User entered an indoor area.
- `indoorLocationManager(_:enteredOutdoorArea: SystemGeofence)`: User entered an outdoor area.
- `indoorLocationManager(_:enteredMappedArea: SystemGeofence)`: User entered a mapped area.
- `indoorLocationManager(_:enteredNotMappedArea: SystemGeofence)`: User entered a non-mapped area.
- `indoorLocationManager(_:buildingTransitionGeofence:exitedBuilding:enteredBuilding:)`: Notifies when a building transition occurs across a geofence.
- `indoorLocationManager(_:triggeredIndoorGeofence:event:indoorGeofence:indoorGeofenceResponse:)`: Triggered when an security geofence event occurs (Security Geofences are: `Crowd Management Areas` and `Restricted Areas`)

#### Miscellaneous
- `indoorLocationManager(_:calibrationIsNeeded: Bool)`: Notifies if the device geomagnetic sensors require calibration.
- `indoorLocationManager(_:poisForFloor:fullStandardPois:servicePois:)`: Provides the list of POIs for the current floor. (**Note**: while the Level object already contains StandardPoi references, this method provides FullStandardPoi objects, which offer more comprehensive data).
- `indoorLocationManager(_:poisForLocation:standardPois:servicePois:)`: Provides the list of POIs for a specific location.
- `indoorLocationManager(_:licenseIsValid: Bool)`: Notifies the status of the license after a check.

---

## Swift Streams Support

For developers who prefer modern Swift concurrency, the SDK also provides all the core functionalities via **Swift Streams** (`AsyncStream`).

Instead of using a delegate, you can subscribe to various `AsyncStream` properties exposed by the `IONStreamProtocol`. This allows you to handle updates using `for await` loops:

- `positionValues`: Stream of `CLLocation` updates.
- `headingValues`: Stream of `Double` heading updates.
- `floorValues`: Stream of `Level` updates.
- `calibrationValues`: Stream of `Bool` calibration status.
- `buildingValues`: Stream of building entry/exit events.
- `venueValues`: Stream of venue entry/exit events.
- `geofenceValues`: Stream of geofence triggers.
- `poiValues`: Stream of `PoiEvent` updates.
- `poiForLocationValues`: Stream of `PoiForLocationEvent` updates.
- `buildingTransitionGeofenceValues`: Stream of `BuildingTransitionGeofenceEvent` updates.
- `enteredNotMappedAreaValues`: Stream of `SystemGeofence` when entering a non-mapped area.
- `enteredMappedAreaValues`: Stream of `SystemGeofence` when entering a mapped area.
- `enteredOutdoorAreaValues`: Stream of `SystemGeofence` when entering an outdoor area.
- `enteredIndoorAreaValues`: Stream of `SystemGeofence` when entering an indoor area.

This stream-based approach provides the same robust functionality as the delegate pattern but in a more reactive and asynchronous style.

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

- **POI (Protocol)**: The base protocol for all POI types, ensuring they have at least a unique identifier.
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
- **WebSocialLinks**: Social media links (Instagram, Facebook, Yelp, LinkedIn, X, Other).
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

- **LightBuilding**: A lightweight model representing a building within a location.
  - `name`: Name of the building.
  - `id`: Unique identifier.
  - `beacons_base_uuids`: A list of base UUIDs for all Bluetooth beacons belonging to this structure.
  - `address`: The physical mailing address of the building.

- **Building**: Represents a full physical structure within a location.
  - `name`: Name of the building.
  - `id`: Unique identifier.
  - `address`: Physical address.
  - `beacons_base_uuids`: List of base UUIDs for beacons in this building.
  - `ground_level`: The floor number designated as ground level.
  - `levels`: Array of `Level` objects representing the floors.

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

- **NavigationMap**: A wrapper for map-related data.
  - `map`: A `LevelMap` object containing the floorplan and positioning details.

- **LevelMap**: Contains technical specifications for a floor's positioning.
  - `map_floor_url`: URL of the floorplan image.
  - `width` / `height`: Dimensions of the map in meters.
  - `rotation`: Map rotation relative to geographical north.
  - `georeference`: Reference points for alignment (`[GeoCoordinate]`).
  - `beacons`: List of `Beacon` objects deployed on this floor.

- **Beacon**: Represents a BLE sensor used for indoor positioning.
  - `uuid`, `major`, `minor`: Proximity UUID and identification numbers.

- **GeoCoordinate**: A basic structure for geographical positioning.
  - `lat`: Latitude.
  - `lng`: Longitude.

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
  - `coordinates`: Geographical coordinates. Can be `[Double, Double]` for Points or `[[Double, Double]]` for LineStrings.
- **Properties**: Navigation attributes for a route segment.
  - `instructionType`: The type of navigation instruction (`NavInstructionType`).
  - `instruction`: Human-readable navigation instruction.
  - `distanceMeters`: Optional length of the segment in meters.
  - `floorMapId`: ID of the floor map where this segment is located.
  - `floorFrom` / `floorTo`: Optional floor names for transitions.
  - `connectorSubType`: Optional type of transition connector (`ConnectorSubType`).
  - `waypointIndex`: Optional index of the associated waypoint.

#### Routing Enums

- **NavInstructionType**: Defines navigation actions (e.g., `walk`, `turnLeft`, `takeElevator`, `arrive`).
- **ConnectorSubType**: Defines connection types between floors (e.g., `stairs`, `elevator`).
- **Meta**: Summary information for the route.
  - `estimatedTimeSeconds`: Total estimated time.
  - `totalDistanceMeters`: Total distance.
  - `floorChanges`: Number of floor changes.
  - `floorMapIds`: List of all floor map IDs involved.

- **Waypoint**: Represents a point on a route.
  - `coordinate`: Geographical position (`GeoCoordinate`).
  - `floorId`: Unique identifier of the level.

