[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/kitasuke/Cardio)

# Cardio
Simple HealthKit wrapper for workout in watchOS 2

## Features

## Usage

- Extend `Context` protocol and set your favorite types
```swift
public protocol Context {
    var activityType: HKWorkoutActivityType { get }
    var locationType: HKWorkoutSessionLocationType { get }
    
    var distanceUnit: HKUnit { get }
    var activeEnergyUnit: HKUnit { get }
    var heartRateUnit: HKUnit { get }

    var distanceType: HKQuantityType { get }
    var activeEnergyType: HKQuantityType { get }
    var heartRateType: HKQuantityType { get }
    
    var shareIdentifiers: [String] { get }
    var readIdentifiers: [String] { get }
}
```

- Initialize `Cardio` with context
```swift
let cardio = Cardio(context: context)
```

- Authorize HealthKit to access
```swift
cardio.authorize { result in
}
```

- Set update handler(optional)
```swift
cardio.distanceHandler = { distance, total in
}

cardio.activeEnergyHandler = { activeEnergy, total in
}

cardio.heartRateHandler = { heartRate, average in
}
```

- Start your workout session
```swift
cardio.start { result in
}
```
- End your workout session
```swift
cardio.end { result in
}
```

See more detail in Demo project

## Requirements

watchOS 2.0+  
Swift 2.0+

## Installation

**Add HealthKit entitlement in Capabilities tab for your both containing app target and WatchKit extension target**

### Carthage
Cardio is available through [Carthage](https://github.com/Carthage/Carthage).

To install Cardio into your Xcode project using Carthage, specify it in your Cartfile:

```ruby
github "kitasuke/Cardio"
```

Then, run `carthage update`

You can see `Cardio.framework` and `Result.framework` in `Carthage/Build/watchOS/` now, so drag and drop them to `Embedded Binaries` in General menu tab for your WatchKit Extension.

In case you haven't installed Carthage yet, run the following command

```ruby
$ brew update
$ brew install carthage
```

### Manual

Copy all the files in `Cardio` and `Carthage/Checkouts/Result/Result` directory into your WatchKit Extension.


## License

Cardio is available under the MIT license. See the [LICENSE](https://github.com/kitasuke/Cardio/blob/master/LICENSE) file for more info.
