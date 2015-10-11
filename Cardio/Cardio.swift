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

public class Cardio: NSObject, HKWorkoutSessionDelegate {
    let context: Context
    let healthStore: HKHealthStore
    let workoutSession: HKWorkoutSession
    
    private var startHandler: (Result<(HKWorkoutSession, NSDate), CardioError> -> Void)?
    private var endHandler: (Result<(HKWorkoutSession, NSDate), CardioError> -> Void)?
    public var updateHandler: ((HKQuantity) -> Void)?
    
    private var startDate: NSDate?
    private var endDate: NSDate?
    
    private var queries = [HKQuery]()
    
    var currentDistanceQuantity: HKQuantity
    var currentActiveEnergyQuantity: HKQuantity
    var currentHeartRateQuantity: HKQuantity
    
    var distanceQuantities = [HKQuantitySample]()
    var activeEnergyQuantities = [HKQuantitySample]()
    var heartRateQuantities = [HKQuantitySample]()
    
    // MARK: - Initializer
    
    public init <T: Context>(context: T) {
        self.context = context
        self.healthStore = HKHealthStore()
        self.workoutSession = HKWorkoutSession(activityType: context.activityType, locationType: context.locationType)
        
        self.currentDistanceQuantity = HKQuantity(unit: context.distanceUnit, doubleValue: 0.0)
        self.currentActiveEnergyQuantity = HKQuantity(unit: context.activeEnergyUnit, doubleValue: 0.0)
        self.currentHeartRateQuantity = HKQuantity(unit: context.heartRateUnit, doubleValue: 0.0)
        
        super.init()
        
        self.workoutSession.delegate = self
    }
    
    // MARK: - Public
    
    public func authorize(handler: (Result<(), CardioError>) -> Void = { r in }) {
        guard HKHealthStore.isHealthDataAvailable() else {
            handler(.Failure(.UnsupportedDeviceError))
            return
        }
        
        let shareTypes = context.shareIdentifiers.flatMap { HKObjectType.quantityTypeForIdentifier($0) }
        let typesToShare = Set([HKWorkoutType.workoutType()] as [HKSampleType] + shareTypes as [HKSampleType])
        let typesToRead = Set(context.readIdentifiers.flatMap { HKObjectType.quantityTypeForIdentifier($0) })
        
        HKHealthStore().requestAuthorizationToShareTypes(typesToShare, readTypes: typesToRead) { (succeeded, error) -> Void in
            let result: Result<(), CardioError>
            if succeeded {
                result = .Failure(.AuthorizationError(error))
            } else {
                result = .Success()
            }
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                handler(result)
            })
        }
    }
    
    public func start(handler: (Result<(HKWorkoutSession, NSDate), CardioError>) -> Void = { r in }) {
        startHandler = handler
        
        healthStore.startWorkoutSession(workoutSession)
    }
    
    public func end(handler: (Result<(HKWorkoutSession, NSDate), CardioError>) -> Void = { r in }) {
        endHandler = handler
        healthStore.endWorkoutSession(workoutSession)
    }
    
    // MARK: - HKWorkoutSessionDelegate

    public func workoutSession(workoutSession: HKWorkoutSession, didChangeToState toState: HKWorkoutSessionState, fromState: HKWorkoutSessionState, date: NSDate) {
        switch toState {
        case .Running:
            startWorkout(date)
            startHandler?(.Success(workoutSession, date))
        case .Ended:
            endWorkout(date)
            endHandler?(.Success(workoutSession, date))
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
    
    private func startWorkout(date: NSDate) {
        startDate = date
        
        queries.append(createStreamingQueries(context.distanceType, date: date))
        queries.append(createStreamingQueries(context.activeEnergyType, date: date))
        queries.append(createStreamingQueries(context.heartRateType, date: date))
        
        queries.forEach { healthStore.executeQuery($0) }
    }
    
    private func endWorkout(date: NSDate) {
        endDate = date
        
        queries.forEach { healthStore.stopQuery($0) }
        queries.removeAll()
        
        saveWorkout()
    }
    
    private func saveWorkout() {
        guard let startDate = self.startDate, endDate = self.endDate else { return }
        
        let quantities = distanceQuantities + activeEnergyQuantities
        let samples = quantities.map { $0 as HKSample }
        
        guard samples.count > 0 else { return }
        
        let totalDistance = distanceQuantities.reduce(0.0) { (distance: Double, sample: HKQuantitySample) in
            return distance + sample.quantity.doubleValueForUnit(context.distanceUnit)
        }
        let totalEnergy = activeEnergyQuantities.reduce(0.0) { (energy: Double, sample: HKQuantitySample) in
            return energy + sample.quantity.doubleValueForUnit(context.activeEnergyUnit)
        }
        
        let workout = HKWorkout(activityType: context.activityType, startDate: startDate, endDate: endDate, duration: endDate.timeIntervalSinceDate(startDate), totalEnergyBurned: HKQuantity(unit: context.activeEnergyUnit, doubleValue: totalEnergy), totalDistance: HKQuantity(unit: context.distanceUnit, doubleValue: totalDistance), metadata: nil)
        
        healthStore.saveObject(workout) { (success, error) in
            guard success else { return }
            
            self.healthStore.addSamples(samples, toWorkout: workout, completion: { (success, error) -> Void in
                guard success else { return }
            })
        }
    }
    
    // MARK: - Query
    
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
    
    private func addSamples<T: HKQuantityType>(type: T, samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample] else { return }
        guard let quantity = samples.last?.quantity else { return }
        
        switch type {
        case context.distanceType:
            currentDistanceQuantity = quantity
            distanceQuantities.appendContentsOf(samples)
        case context.activeEnergyType:
            currentActiveEnergyQuantity = quantity
            activeEnergyQuantities.appendContentsOf(samples)
        case context.heartRateType:
            currentHeartRateQuantity = quantity
            heartRateQuantities.appendContentsOf(samples)
        default: break
        }
        updateHandler?(quantity)
    }
}