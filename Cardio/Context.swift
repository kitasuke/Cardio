//
//  Context.swift
//  Cardio
//
//  Created by Yusuke Kita on 10/4/15.
//  Copyright © 2015 kitasuke. All rights reserved.
//

import Foundation
import HealthKit

public struct Context {
    let healthStore: HKHealthStore
    let activityType: HKWorkoutActivityType
    let locationType: HKWorkoutSessionLocationType
    
    public init(healthStore: HKHealthStore = HKHealthStore(), activityType: HKWorkoutActivityType = .Running, locationType: HKWorkoutSessionLocationType = .Outdoor) {
        self.healthStore = healthStore
        self.activityType = activityType
        self.locationType = locationType
    }
}