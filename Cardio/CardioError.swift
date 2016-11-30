//
//  CardioError.swift
//  Cardio
//
//  Created by Yusuke Kita on 10/4/15.
//  Copyright © 2015 kitasuke. All rights reserved.
//

import Foundation

public enum CardioError: Error {
    case unsupportedDeviceError
    case authorizationError(Error?)

    case sessionAlreadyRunningError(Error)
    case noCurrentSessionError(Error)
    case cannotBeRestartedError(Error)
    
    case invalidDurationError
    case noValidSavedDataError
    case workoutSaveFailedError(Error?)
    case dataSaveFailedError(Error?)
    
    case unexpectedWorkoutConfigurationError(Error)
}
