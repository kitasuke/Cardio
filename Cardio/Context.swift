//
//  Context.swift
//  Cardio
//
//  Created by Yusuke Kita on 10/4/15.
//  Copyright © 2015 kitasuke. All rights reserved.
//

import Foundation
import HealthKit

@available (watchOS 2.0, *)
public enum MetadataHeartRate: String {
    case Average = "Average Heart Rate"
    case Max = "Max Heart Rate"
    case Min = "Min Heart Rate"
}

@available (watchOS 2.0, *)
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
    
    var heartRateMetadata: [MetadataHeartRate] { get }
}

@available (watchOS 2.0, *)
public extension Context {
    public var activityType: HKWorkoutActivityType {
        return .Running
    }
    
    public var locationType: HKWorkoutSessionLocationType {
        return .Outdoor
    }
    
    public var distanceUnit: HKUnit {
        return HKUnit.meterUnitWithMetricPrefix(.Kilo)
    }
    
    public var activeEnergyUnit: HKUnit {
        return HKUnit.kilocalorieUnit()
    }
    
    public var heartRateUnit: HKUnit {
        return HKUnit(fromString: "count/min")
    }
    
    public var distanceType: HKQuantityType {
        return HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDistanceWalkingRunning)!
    }
    
    public var activeEnergyType: HKQuantityType {
        return HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierActiveEnergyBurned)!
    }
    
    public var heartRateType: HKQuantityType {
        return HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate)!
    }
    
    public var shareIdentifiers: [String] {
        return [HKQuantityTypeIdentifierActiveEnergyBurned, HKQuantityTypeIdentifierDistanceWalkingRunning, HKQuantityTypeIdentifierHeartRate]
    }
    
    public var readIdentifiers: [String] {
        return [HKQuantityTypeIdentifierActiveEnergyBurned, HKQuantityTypeIdentifierDistanceWalkingRunning, HKQuantityTypeIdentifierHeartRate]
    }
    
    public var heartRateMetadata: [MetadataHeartRate] {
        return [.Average, .Max, .Min]
    }
}