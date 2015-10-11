//
//  CardioError.swift
//  Cardio
//
//  Created by Yusuke Kita on 10/4/15.
//  Copyright © 2015 kitasuke. All rights reserved.
//

import Foundation

public enum CardioError: ErrorType {
    case UnsupportedDeviceError
    case AuthorizationError(NSError?)

    case SessionAlreadyRunningError(NSError)
    case NoCurrentSessionError(NSError)
    case CannotBeRestartedError(NSError)
    
    case NoValidSavedDataError
    case WorkoutSaveFailedError(NSError?)
    case DataSaveFailedError(NSError?)
}