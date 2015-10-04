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
    let healthStore: HKHealthStore
    let workoutSession: HKWorkoutSession
    private var updateHandler: ((HKWorkoutSession, HKWorkoutSessionState, HKWorkoutSessionState, NSDate) -> Void)?
    private var errorHandler: ((HKWorkoutSession, NSError) -> Void)?
    
    // MARK: - Initializer
    
    public init (context: Context) {
        self.healthStore = context.healthStore
        self.workoutSession = HKWorkoutSession(activityType: context.activityType, locationType: context.locationType)
        
        super.init()
        
        self.workoutSession.delegate = self
    }
    
    // MARK: - Public
    
    public func authorize(shareIdentifiers: [String] = [HKQuantityTypeIdentifierDistanceWalkingRunning], readIdentifiers: [String] = [HKQuantityTypeIdentifierActiveEnergyBurned, HKQuantityTypeIdentifierDistanceWalkingRunning, HKQuantityTypeIdentifierHeartRate], handler: (Result<(), CardioError>) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            handler(.Failure(.UnavalableDeviceError))
            return
        }
        
        let shareTypes = shareIdentifiers.flatMap { HKObjectType.quantityTypeForIdentifier($0) }
        let typesToShare = Set([HKWorkoutType.workoutType()] as [HKSampleType] + shareTypes as [HKSampleType])
        let typesToRead = Set(readIdentifiers.flatMap { HKObjectType.quantityTypeForIdentifier($0) })
        
        healthStore.requestAuthorizationToShareTypes(typesToShare, readTypes: typesToRead, completion: { (result, error) -> Void in
            guard result else {
                handler(.Failure(.AuthorizationError(error)))
                return
            }
            handler(.Success())
        })
    }
    
    public func start(updateHandler: (HKWorkoutSession, HKWorkoutSessionState, HKWorkoutSessionState, NSDate) -> Void, errorHandler: (HKWorkoutSession, NSError) -> Void) {
        self.updateHandler = updateHandler
        self.errorHandler = errorHandler
        
        healthStore.startWorkoutSession(workoutSession)
    }
    
    public func end() {
        healthStore.endWorkoutSession(workoutSession)
    }
    
    // MARK: - HKWorkoutSessionDelegate

    public func workoutSession(workoutSession: HKWorkoutSession, didChangeToState toState: HKWorkoutSessionState, fromState: HKWorkoutSessionState, date: NSDate) {
        updateHandler?(workoutSession, toState, fromState, date)
    }
    
    public func workoutSession(workoutSession: HKWorkoutSession, didFailWithError error: NSError) {
        errorHandler?(workoutSession, error)
    }
}