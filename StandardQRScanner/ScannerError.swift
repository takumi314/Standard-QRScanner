//
//  ScannerError.swift
//  StandardQRScanner
//
//  Created by NishiokaKohei on 25/03/2020.
//  Copyright © 2020 Takumi. All rights reserved.
//

import Foundation
import AVFoundation

public enum ScannerError: Error {
    case unauthorized(AVAuthorizationStatus)
    case unavailable(DeviceError)
    case readFailure
    case unknown

    public enum DeviceError {
        case videoUnavailable
        case inputInvalid
        case metadataOutputFailure
        case videoDataOutputFailure
    }
}


