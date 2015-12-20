//
//  Cardio.swift
//  Cardio
//
//  Created by Yusuke Kita on 10/4/15.
//  Copyright © 2015 kitasuke. All rights reserved.
//

import Foundation
import HealthKit
import Result

@available (watchOS 2.0, *)
final public class Cardio: NSObject, HKWorkoutSessionDelegate {
    private let context: ContextType
    private let healthStore: HKHealthStore
    private var workoutSession: HKWorkoutSession?
    
    public private(set) var state: State = .NotStarted
    
    private var startHandler: (Result<(HKWorkoutSession, NSDate), CardioError> -> Void)?
    private var endHandler: (Result<(HKWorkoutSession, NSDate), CardioError> -> Void)?
    
    public var distanceHandler: ((Double, Double) -> Void)?
    public var activeEnergyHandler: ((Double, Double) -> Void)?
    public var heartRateHandler: ((Double, Double) -> Void)?
    
    private var startDate = NSDate()
    private var endDate = NSDate()
    private var pauseDate = NSDate()
    private var pauseDuration: NSTimeInterval = 0
    
    private lazy var queries = [HKQuery]()
    
    private lazy var distanceQuantities = [HKQuantitySample]()
    private lazy var activeEnergyQuantities = [HKQuantitySample]()
    private lazy var heartRateQuantities = [HKQuantitySample]()
    
    public enum State {
        case NotStarted
        case Running
        case Paused
        case Ended
    }
    
    // MARK: - Initializer
    
    public init <T: ContextType>(context: T) {
        self.context = context
        self.healthStore = HKHealthStore()
        self.workoutSession = HKWorkoutSession(activityType: context.activityType, locationType: context.locationType)
        
        super.init()
        
        self.workoutSession!.delegate = self
    }
    
    // MARK: - Public
    
    public func isAuthorized() -> Bool {
        var result = true
        let shareTypes = context.shareIdentifiers.flatMap { HKObjectType.quantityTypeForIdentifier($0) } + [HKWorkoutType.workoutType()]
        shareTypes.forEach {
            switch healthStore.authorizationStatusForType($0) {
            case .SharingAuthorized: return
            default: result = false
            }
        }
        return result
    }
    
    public func authorize(handler: (Result<(), CardioError>) -> Void = { r in }) {
        guard HKHealthStore.isHealthDataAvailable() else {
            handler(.Failure(.UnsupportedDeviceError))
            return
        }
        
        let shareIdentifiers = context.shareIdentifiers.flatMap { HKObjectType.quantityTypeForIdentifier($0) }
        let shareTypes = Set([HKWorkoutType.workoutType()] as [HKSampleType] + shareIdentifiers as [HKSampleType])
        let readTypes = Set(context.readIdentifiers.flatMap { HKObjectType.quantityTypeForIdentifier($0) })
        
        HKHealthStore().requestAuthorizationToShareTypes(shareTypes, readTypes: readTypes) { (success, error) -> Void in
            let result: Result<(), CardioError>
            if success {
                result = .Success()
            } else {
                result = .Failure(.AuthorizationError(error))
            }
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                handler(result)
            })
        }
    }
    
    public func start(handler: (Result<(HKWorkoutSession, NSDate), CardioError>) -> Void = { r in }) {
        startHandler = handler
        
        defer {
            healthStore.startWorkoutSession(workoutSession!)
        }
        
        guard workoutSession == nil else { return }
        workoutSession = HKWorkoutSession(activityType: context.activityType, locationType: context.locationType)
        workoutSession!.delegate = self
    }
    
    public func end(handler: (Result<(HKWorkoutSession, NSDate), CardioError>) -> Void = { r in }) {
        guard let workoutSession = self.workoutSession else { return }
        
        endHandler = handler
        healthStore.endWorkoutSession(workoutSession)
    }
    
    public func pause() {
        pauseDate = NSDate()
        state = .Paused
        
        stopQuery()
    }
    
    public func resume() {
        let resumeDate = NSDate()
        pauseDuration = resumeDate.timeIntervalSinceDate(pauseDate)
        state = .Running
        
        startQuery(resumeDate)
    }
    
    public func save(var metadata: [String: AnyObject] = [:], handler: (Result<HKWorkout, CardioError>) -> Void = { r in }) {
        guard case .OrderedDescending = endDate.compare(startDate) else {
            handler(.Failure(.InvalidDurationError))
            return
        }
        
        let quantities = distanceQuantities + activeEnergyQuantities + heartRateQuantities
        let samples = quantities.map { $0 as HKSample }
        
        guard samples.count > 0 else {
            handler(.Failure(.NoValidSavedDataError))
            return
        }
        
        heartRateMetadata().forEach { key, value in
            metadata[key] = value
        }
        
        // values to save
        let totalDistance = totalValue(context.distanceUnit)
        let totalActiveEnergy = totalValue(context.activeEnergyUnit)
        
        // workout data with metadata
        let workout = HKWorkout(activityType: context.activityType, startDate: startDate, endDate: endDate, duration: endDate.timeIntervalSinceDate(startDate) - pauseDuration, totalEnergyBurned: HKQuantity(unit: context.activeEnergyUnit, doubleValue: totalActiveEnergy), totalDistance: HKQuantity(unit: context.distanceUnit, doubleValue: totalDistance), metadata: metadata)
        
        // save workout
        healthStore.saveObject(workout) { [weak self] (success, error) in
            guard success else {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    handler(.Failure(.WorkoutSaveFailedError(error)))
                })
                return
            }
            
            // save distance, active energy and heart rate themselves
            self?.healthStore.addSamples(samples, toWorkout: workout, completion: { (success, error) -> Void in
                let result: Result<HKWorkout, CardioError>
                if success {
                    result = .Success(workout)
                } else {
                    result = .Failure(.DataSaveFailedError(error))
                }
                
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    handler(result)
                })
            })
        }
    }
    
    // MARK: - HKWorkoutSessionDelegate

    public func workoutSession(workoutSession: HKWorkoutSession, didChangeToState toState: HKWorkoutSessionState, fromState: HKWorkoutSessionState, date: NSDate) {
        switch toState {
        case .Running:
            startWorkout(workoutSession, date: date)
        case .Ended:
            endWorkout(workoutSession, date: date)
        default: break
        }
    }
    
    public func workoutSession(workoutSession: HKWorkoutSession, didFailWithError error: NSError) {
        switch workoutSession.state {
        case .NotStarted:
            endHandler?(.Failure(.NoCurrentSessionError(error)))
        case .Running:
            startHandler?(.Failure(.SessionAlreadyRunningError(error)))
        case .Ended:
            startHandler?(.Failure(.CannotBeRestartedError(error)))
        }
    }
    
    // MARK: - Private
    
    private func startWorkout(workoutSession: HKWorkoutSession, date: NSDate) {
        startDate = date
        state = .Running
        
        startQuery(startDate)
        
        startHandler?(.Success(workoutSession, date))
    }
    
    private func endWorkout(workoutSession: HKWorkoutSession, date: NSDate) {
        endDate = date
        state = .Ended
        
        stopQuery()
        self.workoutSession = nil
        
        endHandler?(.Success(workoutSession, date))
    }
    
    // MARK: - Query
    
    private func startQuery(date: NSDate) {
        queries.append(createStreamingQueries(context.distanceType, date: date))
        queries.append(createStreamingQueries(context.activeEnergyType, date: date))
        queries.append(createStreamingQueries(context.heartRateType, date: date))
        
        queries.forEach { healthStore.executeQuery($0) }
    }
    
    private func stopQuery() {
        queries.forEach { healthStore.stopQuery($0) }
        queries.removeAll(keepCapacity: true)
    }
    
    private func createStreamingQueries<T: HKQuantityType>(type: T, date: NSDate) -> HKQuery {
        let predicate = HKQuery.predicateForSamplesWithStartDate(date, endDate: nil, options: .None)
        
        let query = HKAnchoredObjectQuery(type: type, predicate: predicate, anchor: nil, limit: Int(HKObjectQueryNoLimit)) { (query, samples, deletedObjects, anchor, error) -> Void in
            self.addSamples(type, samples: samples)
        }
        query.updateHandler = { (query, samples, deletedObjects, anchor, error) -> Void in
            self.addSamples(type, samples: samples)
        }
        
        return query
    }
    
    private func addSamples(type: HKQuantityType, samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample] else { return }
        guard let quantity = samples.last?.quantity else { return }
        
        let unit: HKUnit
        switch type {
        case context.distanceType:
            distanceQuantities.appendContentsOf(samples)
            
            unit = context.distanceUnit
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.distanceHandler?(quantity.doubleValueForUnit(unit), self.totalValue(unit))
            })
        case context.activeEnergyType:
            activeEnergyQuantities.appendContentsOf(samples)
            
            unit = context.activeEnergyUnit
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.activeEnergyHandler?(quantity.doubleValueForUnit(unit), self.totalValue(unit))
            })
        case context.heartRateType:
            heartRateQuantities.appendContentsOf(samples)
            
            unit = context.heartRateUnit
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.heartRateHandler?(quantity.doubleValueForUnit(unit), self.averageHeartRate())
            })
        default: return
        }
    }
    
    // MARK: - Calculator
    
    private func totalValue(unit: HKUnit) -> Double {
        let quantities: [HKQuantitySample]
        switch unit {
        case context.distanceUnit:
            quantities = distanceQuantities
        case context.activeEnergyUnit:
            quantities = activeEnergyQuantities
        case context.heartRateUnit:
            quantities = heartRateQuantities
        default:
            quantities = [HKQuantitySample]()
        }
        
        return quantities.reduce(0.0) { (value: Double, sample: HKQuantitySample) in
            return value + sample.quantity.doubleValueForUnit(unit)
        }
    }
    
    private func averageHeartRate() -> Double {
        let totalHeartRate = totalValue(context.heartRateUnit)
        guard totalHeartRate > 0 else { return 0.0 }
        
        let averageHeartRate = totalHeartRate / Double(heartRateQuantities.count)
        return averageHeartRate
    }
    
    // MARK: - Metadata
    
    private func heartRateMetadata() -> [String: AnyObject] {
        var metadata = [String: AnyObject]()
        guard context.heartRateMetadata.count > 0 else { return metadata }
        
        if context.heartRateMetadata.contains(.Average) {
            let averageHeartRate = Int(self.averageHeartRate())
            if averageHeartRate > 0 {
                metadata[MetadataHeartRate.Average.rawValue] = averageHeartRate
            }
        }
        
        let heartRates = heartRateQuantities.map { $0.quantity.doubleValueForUnit(context.heartRateUnit) }
        if context.heartRateMetadata.contains(.Max), let maxHeartRate = heartRates.maxElement() {
            metadata[MetadataHeartRate.Max.rawValue] = maxHeartRate
        }
        if context.heartRateMetadata.contains(.Min), let minHeartRate = heartRates.minElement() {
            metadata[MetadataHeartRate.Min.rawValue] = minHeartRate
        }
        return metadata
    }
}