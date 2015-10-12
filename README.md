[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/kitasuke/Cardio)

# Cardio
Simple HealthKit wrapper for workout in watchOS 2

## Usage

## Requirements

watchOS 2.0+  
Swift 2.0+

## Installation

### Carthage
Cardio is available through [Carthage](https://github.com/Carthage/Carthage).

To install Cardio into your Xcode project using Carthage, specify it in your Cartfile:

```ruby
github "kitasuke/Cardio"
```

Then, run `carthage update`

You can see `Cardio.framework` and `Result.framework` in `Carthage/Build/watchOS/` now, so drag and drop them to `Embedded Binaries` in General menu tab with your WatchKit Extension.

In case you haven't installed Carthage yet, run the following command

```ruby
$ brew update
$ brew install carthage
```

### Manual

Copy all the files in `Cardio` and `Carthage/Checkouts/Result/Result` directory into your WatchKit Extension.


## License

Cardio is available under the MIT license. See the [LICENSE](https://github.com/kitasuke/Cardio/blob/master/LICENSE) file for more info.
