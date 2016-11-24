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
    fileprivate let context: ContextType
    fileprivate let healthStore: HKHealthStore
    fileprivate var workoutSession: HKWorkoutSession?
    
    public fileprivate(set) var state: State = .notStarted
    
    fileprivate var startHandler: ((Result<(HKWorkoutSession, Date), CardioError>) -> Void)?
    fileprivate var endHandler: ((Result<(HKWorkoutSession, Date), CardioError>) -> Void)?
    
    public var distanceHandler: ((Double, Double) -> Void)?
    public var activeEnergyHandler: ((Double, Double) -> Void)?
    public var heartRateHandler: ((Double, Double) -> Void)?
    
    fileprivate var startDate = Date()
    fileprivate var endDate = Date()
    fileprivate var pauseDate = Date()
    fileprivate var pauseDuration: TimeInterval = 0
    
    fileprivate lazy var queries = [HKQuery]()
    
    fileprivate lazy var distanceQuantities = [HKQuantitySample]()
    fileprivate lazy var activeEnergyQuantities = [HKQuantitySample]()
    fileprivate lazy var heartRateQuantities = [HKQuantitySample]()
    
    public enum State {
        case notStarted
        case running
        case paused
        case ended
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
        let shareTypes = context.shareIdentifiers.flatMap { HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: $0)) } + [HKWorkoutType.workoutType()]
        shareTypes.forEach {
            switch healthStore.authorizationStatus(for: $0) {
            case .sharingAuthorized: return
            default: result = false
            }
        }
        return result
    }
    
    public func authorize(_ handler: @escaping (Result<(), CardioError>) -> Void = { r in }) {
        guard HKHealthStore.isHealthDataAvailable() else {
            handler(.failure(.unsupportedDeviceError))
            return
        }
        
        let shareIdentifiers = context.shareIdentifiers.flatMap { HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: $0)) }
        let shareTypes = Set([HKWorkoutType.workoutType()] as [HKSampleType] + shareIdentifiers as [HKSampleType])
        let readTypes = Set(context.readIdentifiers.flatMap { HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: $0)) })
        
        HKHealthStore().requestAuthorization(toShare: shareTypes, read: readTypes) { (success, error) -> Void in
            let result: Result<(), CardioError>
            if success {
                result = .success()
            } else {
                result = .failure(.authorizationError(error))
            }
            DispatchQueue.main.async(execute: { () -> Void in
                handler(result)
            })
        }
    }
    
    public func start(_ handler: @escaping (Result<(HKWorkoutSession, Date), CardioError>) -> Void = { r in }) {
        startHandler = handler
        
        defer {
            healthStore.start(workoutSession!)
        }
        
        guard workoutSession == nil else { return }
        workoutSession = HKWorkoutSession(activityType: context.activityType, locationType: context.locationType)
        workoutSession!.delegate = self
    }
    
    public func end(_ handler: @escaping (Result<(HKWorkoutSession, Date), CardioError>) -> Void = { r in }) {
        guard let workoutSession = self.workoutSession else { return }
        
        endHandler = handler
        healthStore.end(workoutSession)
    }
    
    public func pause() {
        pauseDate = Date()
        state = .paused
        
        stopQuery()
    }
    
    public func resume() {
        let resumeDate = Date()
        pauseDuration = resumeDate.timeIntervalSince(pauseDate)
        state = .running
        
        startQuery(resumeDate)
    }
    
    public func save(_ metadata: [String: AnyObject] = [:], handler: @escaping (Result<HKWorkout, CardioError>) -> Void = { r in }) {
        var metadata = metadata
        guard case .orderedDescending = endDate.compare(startDate) else {
            handler(.failure(.invalidDurationError))
            return
        }
        
        let quantities = distanceQuantities + activeEnergyQuantities + heartRateQuantities
        let samples = quantities.map { $0 as HKSample }
        
        guard samples.count > 0 else {
            handler(.failure(.noValidSavedDataError))
            return
        }
        
        heartRateMetadata().forEach { key, value in
            metadata[key] = value
        }
        
        // values to save
        let totalDistance = totalValue(context.distanceUnit)
        let totalActiveEnergy = totalValue(context.activeEnergyUnit)
        
        // workout data with metadata
        let workout = HKWorkout(activityType: context.activityType, start: startDate, end: endDate, duration: endDate.timeIntervalSince(startDate) - pauseDuration, totalEnergyBurned: HKQuantity(unit: context.activeEnergyUnit, doubleValue: totalActiveEnergy), totalDistance: HKQuantity(unit: context.distanceUnit, doubleValue: totalDistance), metadata: metadata)
        
        // save workout
        healthStore.save(workout, withCompletion: { [weak self] (success, error) in
            guard success else {
                DispatchQueue.main.async(execute: { () -> Void in
                    handler(.failure(.workoutSaveFailedError(error)))
                })
                return
            }
            
            // save distance, active energy and heart rate themselves
            self?.healthStore.add(samples, to: workout, completion: { (success, error) -> Void in
                let result: Result<HKWorkout, CardioError>
                if success {
                    result = .success(workout)
                } else {
                    result = .failure(.dataSaveFailedError(error))
                }
                
                DispatchQueue.main.async(execute: { () -> Void in
                    handler(result)
                })
            })
        }) 
    }
    
    // MARK: - HKWorkoutSessionDelegate

    public func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        switch toState {
        case .running:
            startWorkout(workoutSession, date: date)
        case .ended:
            endWorkout(workoutSession, date: date)
        default: break
        }
    }
    
    public func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        switch workoutSession.state {
        case .notStarted:
            endHandler?(.failure(.noCurrentSessionError(error)))
        case .running:
            startHandler?(.failure(.sessionAlreadyRunningError(error)))
        case .ended:
            startHandler?(.failure(.cannotBeRestartedError(error)))
        case .paused:
            // TODO
            break
        }
    }
    
    // MARK: - Private
    
    fileprivate func startWorkout(_ workoutSession: HKWorkoutSession, date: Date) {
        startDate = date
        state = .running
        
        startQuery(startDate)
        
        startHandler?(.success(workoutSession, date))
    }
    
    fileprivate func endWorkout(_ workoutSession: HKWorkoutSession, date: Date) {
        endDate = date
        state = .ended
        
        stopQuery()
        self.workoutSession = nil
        
        endHandler?(.success(workoutSession, date))
    }
    
    // MARK: - Query
    
    fileprivate func startQuery(_ date: Date) {
        queries.append(createStreamingQueries(context.distanceType, date: date))
        queries.append(createStreamingQueries(context.activeEnergyType, date: date))
        queries.append(createStreamingQueries(context.heartRateType, date: date))
        
        queries.forEach { healthStore.execute($0) }
    }
    
    fileprivate func stopQuery() {
        queries.forEach { healthStore.stop($0) }
        queries.removeAll(keepingCapacity: true)
    }
    
    fileprivate func createStreamingQueries<T: HKQuantityType>(_ type: T, date: Date) -> HKQuery {
        let predicate = HKQuery.predicateForSamples(withStart: date, end: nil, options: HKQueryOptions())
        
        let query = HKAnchoredObjectQuery(type: type, predicate: predicate, anchor: nil, limit: Int(HKObjectQueryNoLimit)) { (query, samples, deletedObjects, anchor, error) -> Void in
            self.addSamples(type, samples: samples)
        }
        query.updateHandler = { (query, samples, deletedObjects, anchor, error) -> Void in
            self.addSamples(type, samples: samples)
        }
        
        return query
    }
    
    fileprivate func addSamples(_ type: HKQuantityType, samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample] else { return }
        guard let quantity = samples.last?.quantity else { return }
        
        let unit: HKUnit
        switch type {
        case context.distanceType:
            distanceQuantities.append(contentsOf: samples)
            
            unit = context.distanceUnit
            DispatchQueue.main.async(execute: { () -> Void in
                self.distanceHandler?(quantity.doubleValue(for: unit), self.totalValue(unit))
            })
        case context.activeEnergyType:
            activeEnergyQuantities.append(contentsOf: samples)
            
            unit = context.activeEnergyUnit
            DispatchQueue.main.async(execute: { () -> Void in
                self.activeEnergyHandler?(quantity.doubleValue(for: unit), self.totalValue(unit))
            })
        case context.heartRateType:
            heartRateQuantities.append(contentsOf: samples)
            
            unit = context.heartRateUnit
            DispatchQueue.main.async(execute: { () -> Void in
                self.heartRateHandler?(quantity.doubleValue(for: unit), self.averageHeartRate())
            })
        default: return
        }
    }
    
    // MARK: - Calculator
    
    fileprivate func totalValue(_ unit: HKUnit) -> Double {
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
            return value + sample.quantity.doubleValue(for: unit)
        }
    }
    
    fileprivate func averageHeartRate() -> Double {
        let totalHeartRate = totalValue(context.heartRateUnit)
        guard totalHeartRate > 0 else { return 0.0 }
        
        let averageHeartRate = totalHeartRate / Double(heartRateQuantities.count)
        return averageHeartRate
    }
    
    // MARK: - Metadata
    
    fileprivate func heartRateMetadata() -> [String: AnyObject] {
        var metadata = [String: AnyObject]()
        guard context.heartRateMetadata.count > 0 else { return metadata }
        
        if context.heartRateMetadata.contains(.Average) {
            let averageHeartRate = Int(self.averageHeartRate())
            if averageHeartRate > 0 {
                metadata[MetadataHeartRate.Average.rawValue] = averageHeartRate as AnyObject?
            }
        }
        
        let heartRates = heartRateQuantities.map { $0.quantity.doubleValue(for: context.heartRateUnit) }
        if context.heartRateMetadata.contains(.Max), let maxHeartRate = heartRates.max() {
            metadata[MetadataHeartRate.Max.rawValue] = maxHeartRate as AnyObject?
        }
        if context.heartRateMetadata.contains(.Min), let minHeartRate = heartRates.min() {
            metadata[MetadataHeartRate.Min.rawValue] = minHeartRate as AnyObject?
        }
        return metadata
    }
}
