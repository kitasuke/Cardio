//
//  CardioError.swift
//  Cardio
//
//  Created by Yusuke Kita on 10/4/15.
//  Copyright © 2015 kitasuke. All rights reserved.
//

import Foundation

public enum CardioError: ErrorType {
    case UnavalableDeviceError
    case InvalidInputError
    case AuthorizationError(NSError?)
}