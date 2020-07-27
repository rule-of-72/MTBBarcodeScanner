//
//  MTBBarcodeScannerError.swift
//
//  Created by Sam Mortazavi on 21/7/20.
//

public enum MTBBarcodeScannerError: Error {
    
    public enum ScannerStartError: Error {
        case cameraNotPresent
        case scanningProhibited
        case sessionAlreadyActive
    }
    
    public enum StillImageCaptureError: Error {
        case captureInProgress
        case imageCreationFailed
        case sessionIsClosed
            
    }
    
    public enum CameraSetError: Error {
        case sessionNotRunning
        case noCaptureDeviceAvailable
    }

    public enum CameraFlipError: Error {
        case notScanning
        case cameraNotSet
    }
    
    case torchModeUnavailable
}


extension MTBBarcodeScannerError.ScannerStartError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .cameraNotPresent:
            return "Could not start scanner because the device doesn't have a camera.\nCheck 'requestCameraPermission' method before calling 'startScanning'"
        case .scanningProhibited:
            return "Could not start scanner because scanning is prohibited on this device.\nCheck 'requestCameraPermission' method before calling 'startScanning'"
        case .sessionAlreadyActive:
                return "Another session is in already in use."
        }
    }
}


extension MTBBarcodeScannerError.StillImageCaptureError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .captureInProgress:
            return "Still image capture is already in progress. Check with isCapturingStillImage"
        case .imageCreationFailed:
            return "Failed to create a still image."
        case .sessionIsClosed:
                return "AVCaptureConnection is closed."
            }
    }
}


extension MTBBarcodeScannerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .torchModeUnavailable:
            return "Torch unavailable or mode not supported."
        }
    }
}


extension MTBBarcodeScannerError.CameraSetError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .sessionNotRunning:
            return "Camera cannot be set when session is not running."
        case .noCaptureDeviceAvailable:
            return "Was not able to create any suitable capture device."
        }
    }
}


extension MTBBarcodeScannerError.CameraFlipError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notScanning:
            return "Camera can't be flipped when barcode scanner is not scanning"
        case .cameraNotSet:
            return "Camera can't be flipped because it has not been set yet"
        }
    }
}
