//
//  ContextType.swift
//  Cardio
//
//  Created by Yusuke Kita on 10/4/15.
//  Copyright © 2015 kitasuke. All rights reserved.
//

import Foundation
import HealthKit

#if os(iOS)

public protocol ContextType {
    var activityType: HKWorkoutActivityType { get }
    var locationType: HKWorkoutSessionLocationType { get }
    
    var shareIdentifiers: [String] { get }
    var readIdentifiers: [String] { get }
}
    
extension ContextType {
    public var activityType: HKWorkoutActivityType {
        return .running
    }
    
    public var locationType: HKWorkoutSessionLocationType {
        return .outdoor
    }
    
    public var shareIdentifiers: [String] {
        return [HKQuantityTypeIdentifier.activeEnergyBurned.rawValue, HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue, HKQuantityTypeIdentifier.heartRate.rawValue]
    }
    
    public var readIdentifiers: [String] {
        return [HKQuantityTypeIdentifier.activeEnergyBurned.rawValue, HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue, HKQuantityTypeIdentifier.heartRate.rawValue]
    }
}

#elseif os(watchOS)

public enum MetadataHeartRate: String {
    case Average = "Average Heart Rate"
    case Max = "Max Heart Rate"
    case Min = "Min Heart Rate"
}

public protocol ContextType {
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
    
    var heartRateMetadata: [MetadataHeartRate] { get }
}

public extension ContextType {
    public var activityType: HKWorkoutActivityType {
        return .running
    }
    
    public var locationType: HKWorkoutSessionLocationType {
        return .outdoor
    }
    
    public var distanceUnit: HKUnit {
        return HKUnit.meterUnit(with: .kilo)
    }
    
    public var activeEnergyUnit: HKUnit {
        return HKUnit.kilocalorie()
    }
    
    public var heartRateUnit: HKUnit {
        return HKUnit(from: "count/min")
    }
    
    public var distanceType: HKQuantityType {
        return HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.distanceWalkingRunning)!
    }
    
    public var activeEnergyType: HKQuantityType {
        return HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned)!
    }
    
    public var heartRateType: HKQuantityType {
        return HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!
    }
    
    public var shareIdentifiers: [String] {
        return [HKQuantityTypeIdentifier.activeEnergyBurned.rawValue, HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue, HKQuantityTypeIdentifier.heartRate.rawValue]
    }
    
    public var readIdentifiers: [String] {
        return [HKQuantityTypeIdentifier.activeEnergyBurned.rawValue, HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue, HKQuantityTypeIdentifier.heartRate.rawValue]
    }
    
    public var heartRateMetadata: [MetadataHeartRate] {
        return [.Average, .Max, .Min]
    }
}

#endif
