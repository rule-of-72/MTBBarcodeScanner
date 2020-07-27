//
//  MTBBarcodeScanner.swift
//
//  Created by Sam Mortazavi on 21/7/20.
//

import UIKit


public enum MTBCamera {
    case back
    case front
    
    fileprivate var avPosition: AVCaptureDevice.Position {
        switch self {
        case .back:
            return .back
        case .front:
            return .front
        }
    }
}

/**
 *  Available torch modes when scanning barcodes.
 *
 *  While AVFoundation provides an additional automatic
 *  mode, it is not supported here because it only works
 *  with video recordings, not barcode scanning.
 */
public enum MTBTorchMode {
    case off
    case on
    
    fileprivate var avTorchMode: AVCaptureDevice.TorchMode {
        switch self {
        case .off:
            return .off
        case .on:
            return .on
        }
    }
}


public class MTBBarcodeScanner: NSObject {
    
    /// Starting or stopping the capture session should only be done on this queue.
    private let privateSessionQueue: DispatchQueue
    
    /// The capture session used for scanning barcodes.
    private var session: AVCaptureSession!
    
    /// Represents the physical device that is used for scanning barcodes.
    private var captureDevice: AVCaptureDevice!
    
    /// The layer used to view the camera input. This layer is added to the
    /// previewView when scanning starts.
    private var capturePreviewLayer: AVCaptureVideoPreviewLayer!
    
    /// The current capture device input for capturing video. This is used
    /// to reset the camera to its initial properties when scanning stops.
    private var currentCaptureDeviceInput: AVCaptureDeviceInput!
    
    /// The capture device output for capturing video.
    private var captureOutput: AVCaptureMetadataOutput!
    
    /// The MetaDataObjectTypes to look for in the scanning session.
    ///
    /// Only objects with a AVMetadataObject.ObjectType found in this set will be
    /// reported to the result block.
    private var metaDataObjectTypes: Set<AVMetadataObject.ObjectType>
    
    /// The view used to preview the camera input.
    ///
    /// The AVCaptureVideoPreviewLayer is added to this view to preview the
    /// camera input when scanning starts. When scanning stops, the layer is
    /// removed.
    private let previewView: UIView
    
    /// The auto focus range restriction the AVCaptureDevice was initially configured for when scanning started.
    ///
    /// When startScanning is called, the auto focus range restriction of the default AVCaptureDevice
    /// is stored. When stopScanning is called, the AVCaptureDevice is reset to the initial range restriction
    /// to prevent a bug in the AVFoundation framework.
    private var initialAutoFocusRangeRestriction: AVCaptureDevice.AutoFocusRangeRestriction!
    
    /// The focus point the AVCaptureDevice was initially configured for when scanning started.
    ///
    /// When startScanning is called, the focus point of the default AVCaptureDevice
    /// is stored. When stopScanning is called, the AVCaptureDevice is reset to the initial focal point
    /// to prevent a bug in the AVFoundation framework.
    private var initialFocusPoint: CGPoint!
    
    /// Used for still image capture prior to iOS 10
    private var stillImageOutput: AVCaptureStillImageOutput!
    
    /// If allowTapToFocus is set to YES, this gesture recognizer is added to the `previewView`
    /// when scanning starts. When the user taps the view, the `focusPointOfInterest` will change
    /// to the location the user tapped.
    private var gestureRecognizer: UITapGestureRecognizer!
    
    ///  The currently set camera. See MTBCamera for options.
    ///
    ///  Use [setCamera(_:)](x-source-tag://setCamera) to set or change the camera.
    private(set) var camera: MTBCamera?
    
    ///  Control the torch on the device, if present.
    ///
    ///  Attempting to set the torch mode to an unsupported state
    ///  will fail silently, and the value passed into the setter
    ///  will be discarded.
    ///
    ///  see setTorchMode
    public var torchMode: MTBTorchMode?
    
    ///  Allow the user to tap the previewView to focus a specific area.
    ///  Defaults to YES.
    public var allowTapToFocus = false
    
    ///  If set, only barcodes inside this area will be scanned.
    ///
    ///  Setting this property is only supported while the scanner is active.
    ///  Use the didStartScanningBlock if you want to set it as early as
    ///  possible.
    public var scanRect = CGRect.zero
    
    ///  Layer used to present the camera input. If the previewView
    ///  does not use auto layout, it may be necessary to adjust the layers frame.
    public var previewLayer: CALayer?
    
    /// Auto focus range restriction, if supported.
    ///
    /// Defaults to AVCaptureAutoFocusRangeRestrictionNear. Will be ignored on unsupported devices.
    private var preferredAutoFocusRangeRestriction: AVCaptureDevice.AutoFocusRangeRestriction!
    
    
    @available(iOS 10.0, *)
    private lazy var output: AVCapturePhotoOutput = { AVCapturePhotoOutput()
    }()
    
    
    public weak var delegate: MTBBarcodeScannerDelegate? = nil
    
    
    // MARK: - Default Values
    
    public static var defaultMetaDataObjectTypes: Set<AVMetadataObject.ObjectType> {
        return [.qr,
                .upce,
                .code39,
                .code39Mod43,
                .ean13,
                .ean8,
                .code93,
                .code128,
                .pdf417,
                .aztec,
                .interleaved2of5,
                .itf14,
                .dataMatrix
        ]
        
    }
    
    public let focalPointOfInterestX: CGFloat = 0.5
    public let focalPointOfInterestY: CGFloat = 0.5
    
    
    private override init() {
        fatalError("MTBBarcodeScanner init is not supported. Please use init(previewView:metadataObjectTypes:) to instantiate a MTBBarcodeScanner")
    }
    
    
    public init(previewView: UIView, metaDataObjectTypes: Set<AVMetadataObject.ObjectType> = defaultMetaDataObjectTypes) {
        
        if metaDataObjectTypes.isEmpty {
            // If the metaDataObjectTypes list is empty the default types will be used.
            self.metaDataObjectTypes = MTBBarcodeScanner.defaultMetaDataObjectTypes
        } else {
            // Any type other than the ones in defaultMetaDataObjectTypes (like `.face`, `.humanBody`, etc.) will be ignored because they are not supported by MTBBarcideScanner.
            self.metaDataObjectTypes = metaDataObjectTypes.intersection(MTBBarcodeScanner.defaultMetaDataObjectTypes)
            
        }
        
        self.previewView = previewView
        self.allowTapToFocus = true
        self.preferredAutoFocusRangeRestriction = .near
        self.privateSessionQueue = DispatchQueue(label: "com.mikebuss.MTBBarcodeScanner.captureSession")
        
        super.init()
        
        self.addObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - Scanning
    
    public class var isCameraPresent: Bool {
        // capture device is nil if status is AVAuthorizationStatusRestricted
        return AVCaptureDevice.default(for: .video) != nil
    }
    
    public class func hasCamera(camera: MTBCamera) -> Bool {
        let position: AVCaptureDevice.Position = camera.avPosition
        
        if #available(iOS 10.0, *) {
            
            let device: AVCaptureDevice? = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                                   for: .video,
                                                                   position: position)
            return device != nil
        } else {
            // Array is empty if status is AVAuthorizationStatusRestricted
            for device in AVCaptureDevice.devices(for: .video) {
                if device.position == position {
                    return true
                }
            }
        }
        return false
    }
    
    public class func oppositeCameraOf(camera: MTBCamera) -> MTBCamera {
        switch (camera) {
        case .back:
            return .front
            
        case .front:
            return .back
        }
    }
    
    public class var isScanningProhibited: Bool {
        switch (AVCaptureDevice.authorizationStatus(for: .video)) {
        case .denied, .restricted:
            return true
            
        default:
            return false
        }
    }
    
    public class func requestCameraPermission(successBlock: @escaping (Bool)->Void) {
        if !self.isCameraPresent {
            successBlock(false)
            return
        }
        
        switch (AVCaptureDevice.authorizationStatus(for: .video)) {
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video,
                                          completionHandler: { granted in
                                            DispatchQueue.main.async {
                                                successBlock(granted)
                                            }
            })
        case .authorized:
            successBlock(true)
            
        case .denied, .restricted:
            successBlock(false)
            
        @unknown default:
            // Unknown status, Defaulting to denied status.
            successBlock(false)
        }
        
    }
    
    
    public func startScanning(withCamera camera: MTBCamera = .back) throws -> Void {
        if !MTBBarcodeScanner.isCameraPresent {
            throw MTBBarcodeScannerError.ScannerStartError.cameraNotPresent
        }
        if MTBBarcodeScanner.isScanningProhibited {
            throw MTBBarcodeScannerError.ScannerStartError.scanningProhibited
        }
        
        if (self.session != nil) {
            throw MTBBarcodeScannerError.ScannerStartError.sessionAlreadyActive
        }
        
        // Configure the session
        self.camera = camera
        self.captureDevice = self.newCaptureDevice(withCamera: camera)
        let session: AVCaptureSession = try self.newSession(with: self.captureDevice)
        
        self.session = session
        
        // Configure the preview layer
        self.capturePreviewLayer.cornerRadius = self.previewView.layer.cornerRadius
        self.previewView.layer.insertSublayer(self.capturePreviewLayer, at:0) // Insert below all other views
        self.refreshVideoOrientation()
        
        // Configure 'tap to focus' functionality
        self.configureTapToFocus()
        
        privateSessionQueue.async { [weak self] in
            guard let self = self else { return }
            // Configure the rect of interest
            self.captureOutput.rectOfInterest = self.rectOfInterest(from: self.scanRect)
            
            // Start the session after all configurations:
            // Must be dispatched as it is blocking
            self.session.startRunning()
            if !self.scanRect.isEmpty {
                self.captureOutput.rectOfInterest = self.capturePreviewLayer.metadataOutputRectConverted(fromLayerRect: self.scanRect)
            }
            // Alert the delegate now that we've started scanning.
            // Dispatch back to main
            DispatchQueue.main.async {
                self.delegate?.barcodeScannerDidStartScanning()
            }
        }
    }
    
    public func stopScanning() {
        if (self.session == nil) {
            return
        }
        
        // Turn the torch off
        self.torchMode = .off
        
        // Remove the preview layer
        self.capturePreviewLayer.removeFromSuperlayer()
        
        // Stop recognizing taps for the 'Tap to Focus' feature
        self.stopRecognizingTaps()
        
        //        self.resultBlock = nil
        self.capturePreviewLayer.session = nil
        self.capturePreviewLayer = nil
        
        let session:AVCaptureSession! = self.session
        let deviceInput: AVCaptureDeviceInput? = self.currentCaptureDeviceInput
        self.session = nil
        
        privateSessionQueue.async { [weak self] in
            guard let self = self else { return }
            // When we're finished scanning, reset the settings for the camera
            // to their original states
            // Must be dispatched as it is blocking
            
            // Remove the device input if it was set
            if let deviceInput = deviceInput {
                self.removeDeviceInput(deviceInput, from: session)
            }
            for output: AVCaptureOutput in session.outputs {
                session.removeOutput(output)
            }
            
            // Must be dispatched as it is blocking
            session.stopRunning()
        }
    }
    
    public var isScanning: Bool {
        return self.session.isRunning
    }
    
    public var hasOppositeCamera: Bool {
        guard let camera = camera else { return false }
        let otherCamera = MTBBarcodeScanner.oppositeCameraOf(camera: camera)
        return MTBBarcodeScanner.hasCamera(camera: otherCamera)
    }
    
    
    public func flipCamera() throws {
        guard let camera = self.camera else {
            throw MTBBarcodeScannerError.CameraFlipError.cameraNotSet
        }
        if !self.isScanning {
            throw MTBBarcodeScannerError.CameraFlipError.notScanning
        }
        
        let otherCamera:MTBCamera = MTBBarcodeScanner.oppositeCameraOf(camera: camera)
        try self.setCamera(otherCamera)
    }
    
    
    // MARK: - Tap to Focus
    
    private func configureTapToFocus() {
        if self.allowTapToFocus {
            let tapGesture = UITapGestureRecognizer(target:self, action:#selector(focusTapped(_:)))
            self.previewView.addGestureRecognizer(tapGesture)
            self.gestureRecognizer = tapGesture
        }
    }
    
    @objc private func focusTapped(_ tapGesture: UITapGestureRecognizer) {
        let tapPoint = self.gestureRecognizer.location(in: self.gestureRecognizer.view)
        let devicePoint = self.capturePreviewLayer.captureDevicePointConverted(fromLayerPoint: tapPoint)
        
        guard let device = self.captureDevice else {
            NSLog("Capture device has not been set")
            return
        }
        
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusPointOfInterest = devicePoint
                device.focusMode = .continuousAutoFocus
            }
            device.unlockForConfiguration()
        } catch {
            NSLog("Failed to acquire lock for focus change: \(error)")
        }
        
        self.delegate?.barcodeScanner(didTapToFocusOn: tapPoint)
    }
    
    private func stopRecognizingTaps() {
        gestureRecognizer.isEnabled = false
        if (self.gestureRecognizer != nil) {
            self.previewView.removeGestureRecognizer(self.gestureRecognizer)
        }
    }
    
    
    // MARK: - Rotation
    
    @objc private func handleApplicationDidChangeStatusBarNotification(_ notification:NSNotification) {
        self.refreshVideoOrientation()
    }
    
    private func refreshVideoOrientation() {
        let orientation = UIApplication.shared.statusBarOrientation
        self.capturePreviewLayer.frame = self.previewView.bounds
        if let connection = self.capturePreviewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = self.captureOrientation(for: orientation)
        }
    }
    
    private func captureOrientation(for interfaceOrientation: UIInterfaceOrientation) -> AVCaptureVideoOrientation {
        switch (interfaceOrientation) {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        default:
            return .portrait
        }
    }
    
    
    // MARK: - Background Handling
    
    @objc private func applicationWillEnterForegroundNotification(_ notification:NSNotification) {
        // the torch is switched off when the app is backgrounded so we restore the
        // previous state once the app is foregrounded again
        if let torchMode = torchMode {
            try? self.updateForTorchMode(preferredTorchMode: torchMode)
        }
    }
    
    
    // MARK: - Session Configuration
    
    private func newSession(with captureDevice:AVCaptureDevice!) throws -> AVCaptureSession! {
        let input:AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput.init(device: captureDevice)
        } catch {
            throw error
        }
        
        let newSession = AVCaptureSession()
        self.setDeviceInput(input, for: newSession)
        
        // Set an optimized preset for barcode scanning
        newSession.sessionPreset = AVCaptureSession.Preset.high
        
        self.captureOutput = AVCaptureMetadataOutput()
        self.captureOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        
        newSession.addOutput(self.captureOutput)
        self.captureOutput.metadataObjectTypes = Array(self.metaDataObjectTypes)
        
        newSession.beginConfiguration()
        
        if #available(iOS 10.0, *) {
            self.output = AVCapturePhotoOutput()
            self.output.isHighResolutionCaptureEnabled = true
            
            if newSession.canAddOutput(self.output) {
                newSession.addOutput(self.output)
            }
        } else {
            // Still image capture configuration
            self.stillImageOutput = AVCaptureStillImageOutput()
            self.stillImageOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
            
            if self.stillImageOutput.isStillImageStabilizationSupported {
                self.stillImageOutput.automaticallyEnablesStillImageStabilizationWhenAvailable = true
            }
            
            self.stillImageOutput.isHighResolutionStillImageOutputEnabled = true
            newSession.addOutput(self.stillImageOutput)
        }
        
        self.privateSessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureOutput.rectOfInterest = self.rectOfInterest(from: self.scanRect)
        }
        
        self.capturePreviewLayer = AVCaptureVideoPreviewLayer(session: newSession)
        self.capturePreviewLayer.videoGravity = .resizeAspectFill
        self.capturePreviewLayer.frame = self.previewView.bounds
        
        newSession.commitConfiguration()
        
        return newSession
    }
    
    private func newCaptureDevice(withCamera camera:MTBCamera) -> AVCaptureDevice? {
        var newCaptureDevice:AVCaptureDevice?
        let position:AVCaptureDevice.Position = camera.avPosition
        
        if #available(iOS 10.0, *) {
            let device: AVCaptureDevice? = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                                   for: .video,
                                                                   position: position)
            newCaptureDevice = device
        } else {
            let videoDevices = AVCaptureDevice.devices(for: .video)
            for device in videoDevices {
                if device.position == position {
                    newCaptureDevice = device
                    break
                }
            }
        }
        
        // If the front camera is not available, use the back camera
        if (newCaptureDevice == nil) {
            newCaptureDevice = AVCaptureDevice.default(for: .video)
        }
        
        guard let captureDevice = newCaptureDevice else {
            return nil
        }
        
        
        do {
            
            try captureDevice.lockForConfiguration()
            // Using AVCaptureFocusModeContinuousAutoFocus helps improve scan times
            if captureDevice.isFocusModeSupported(.continuousAutoFocus) {
                captureDevice.focusMode = .continuousAutoFocus
            }
            captureDevice.unlockForConfiguration()
        } catch {
            NSLog("Failed to acquire lock for initial focus mode: \(error)")
        }
        
        return newCaptureDevice
    }
    
    class func devicePosition(for camera: MTBCamera) -> AVCaptureDevice.Position {
        return camera.avPosition
    }
    
    
    // MARK: - Helper Methods
    
    private func addObservers() {
        NotificationCenter.default.addObserver(self,
                                               selector:  #selector(handleApplicationDidChangeStatusBarNotification(_:)),
                                               name: UIApplication.didChangeStatusBarOrientationNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillEnterForegroundNotification(_:)),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
    }
    
    private func setDeviceInput(_ deviceInput: AVCaptureDeviceInput, for session: AVCaptureSession) {
        
        self.removeDeviceInput(self.currentCaptureDeviceInput, from: session)
        
        self.currentCaptureDeviceInput = deviceInput
        self.updateFocusPreferencesOfDevice(deviceInput.device, reset: false)
        session.addInput(deviceInput)
    }
    
    private func removeDeviceInput(_ deviceInput: AVCaptureDeviceInput, from session: AVCaptureSession) {
        
        // Restore focus settings to the previously saved state
        self.updateFocusPreferencesOfDevice(deviceInput.device, reset: true)
        
        session.removeInput(deviceInput)
        self.currentCaptureDeviceInput = nil
    }
    
    private func updateFocusPreferencesOfDevice(_ inputDevice: AVCaptureDevice, reset: Bool) {
        
        do {
            try inputDevice.lockForConfiguration()
        } catch {
            NSLog("Failed to acquire lock to (re)set focus options: \(error)")
            return
        }
        
        // Prioritize the focus on objects near to the device
        if inputDevice.isAutoFocusRangeRestrictionSupported {
            if !reset {
                self.initialAutoFocusRangeRestriction = inputDevice.autoFocusRangeRestriction
                inputDevice.autoFocusRangeRestriction = self.preferredAutoFocusRangeRestriction
            } else {
                inputDevice.autoFocusRangeRestriction = self.initialAutoFocusRangeRestriction
            }
        }
        
        // Focus on the center of the image
        if inputDevice.isFocusPointOfInterestSupported {
            if !reset {
                self.initialFocusPoint = inputDevice.focusPointOfInterest
                inputDevice.focusPointOfInterest = CGPoint(x: focalPointOfInterestX, y: focalPointOfInterestY)
            } else {
                inputDevice.focusPointOfInterest = self.initialFocusPoint
            }
        }
        
        inputDevice.unlockForConfiguration()
        
        // this method will acquire its own lock
        if let torchMode = torchMode {
            try? self.updateForTorchMode(preferredTorchMode: torchMode)
        }
    }
    
    
    // MARK: - Torch Control
    
    public func setTorchMode(torchMode: MTBTorchMode) throws {
        try self.updateForTorchMode(preferredTorchMode: torchMode)
    }
    
    public func toggleTorch() {
        switch (self.torchMode) {
        case .on:
            self.torchMode = .off
            
        case .off:
            self.torchMode = .on
            
        case .none:
            break
        }
    }
    
    private func updateForTorchMode(preferredTorchMode: MTBTorchMode) throws {
        let avTorchMode = preferredTorchMode.avTorchMode
        guard let backCamera = AVCaptureDevice.default(for: .video), backCamera.isTorchAvailable, backCamera.isTorchModeSupported(avTorchMode) else {
            throw MTBBarcodeScannerError.torchModeUnavailable
        }
        
        do {
            try backCamera.lockForConfiguration()
        } catch {
            NSLog("Failed to acquire lock to update torch mode.")
            throw error
        }
        
        backCamera.torchMode = avTorchMode
        backCamera.unlockForConfiguration()
    }
    
    public func hasTorch() -> Bool {
        guard let captureDevice = self.newCaptureDevice(withCamera: .back) else { return false }
        return captureDevice.hasTorch
    }
    
    
    // MARK: - Capture
    
    public func freezeCapture() {
        // we must access the layer on the main thread, but manipulating
        // the capture connection is blocking and should be dispatched
        guard let session = session, let connection = self.capturePreviewLayer.connection else {
            return
        }
        
        self.privateSessionQueue.async {
            connection.isEnabled = false
            session.stopRunning()
        }
    }
    
    public func unfreezeCapture() {
        guard let session = session, let connection = self.capturePreviewLayer.connection else {
            return
        }
        
        if !session.isRunning {
            self.setDeviceInput(self.currentCaptureDeviceInput, for: session)
            
            self.privateSessionQueue.async { [weak self] in
                guard let self = self else { return }
                session.startRunning()
                connection.isEnabled = true
                
                DispatchQueue.main.async {
                    self.delegate?.barcodeScannerDidUnfreezScanner()
                }
            }
        }
    }
    
    
    public func captureStillImage() throws {
        if self.isCapturingStillImage() {
            throw MTBBarcodeScannerError.StillImageCaptureError.captureInProgress
        }
        
        if #available(iOS 10.0, *) {
            let settings = AVCapturePhotoSettings()
            settings.isAutoStillImageStabilizationEnabled = false
            settings.flashMode = .off
            settings.isHighResolutionPhotoEnabled = true
            
            self.privateSessionQueue.async { [weak self] in
                guard let self = self else { return }
                self.output.capturePhoto(with: settings, delegate: self)
                
            }
        } else {
            
            guard let stillConnection = self.stillImageOutput.connection(with: .video) else {
                throw MTBBarcodeScannerError.StillImageCaptureError.sessionIsClosed
            }
            
            self.stillImageOutput.captureStillImageAsynchronously(from: stillConnection) { [weak self] imageDataSampleBuffer, error in
                guard let self = self else { return }
                
                self.processCapturedStillImage(sampleBuffer: imageDataSampleBuffer, error: error)
            }
            
        }
    }
    
    private func processCapturedStillImage(sampleBuffer: CMSampleBuffer?, error: Error?) {
        guard let sampleBuffer = sampleBuffer, error == nil else {
            DispatchQueue.main.async {
                self.delegate?.barcodeScanner(failedToCaptureStillImageWith: error ?? MTBBarcodeScannerError.StillImageCaptureError.imageCreationFailed)
            }
            return
        }
        
        guard let jpegData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer),
            let image = UIImage(data: jpegData) else {
                DispatchQueue.main.async {
                    self.delegate?.barcodeScanner(failedToCaptureStillImageWith: MTBBarcodeScannerError.StillImageCaptureError.imageCreationFailed)
                }
                return
        }
        
        DispatchQueue.main.async {
            self.delegate?.barcodeScanner(didCapture: image)
        }
    }
    
    
    private func isCapturingStillImage() -> Bool {
        return self.stillImageOutput.isCapturingStillImage
    }
    
    
    // MARK: - Setters
    
    /// - Tag: setCamera
    public func setCamera(_ camera: MTBCamera) throws {
        if self.camera == camera {
            return
        }
        
        if !self.isScanning {
            throw MTBBarcodeScannerError.CameraSetError.sessionNotRunning
        }
        
        guard let captureDevice = self.newCaptureDevice(withCamera: camera) else {
            throw MTBBarcodeScannerError.CameraSetError.noCaptureDeviceAvailable
        }
        let input = try AVCaptureDeviceInput(device: captureDevice)
        
        self.setDeviceInput(input, for:self.session)
        self.camera = camera
        
    }
    
    public func setScanRect(scanRect: CGRect) {
        
        if !self.isScanning {
            return
        }
        
        self.refreshVideoOrientation()
        
        self.scanRect = scanRect
        
        // Only set now if scanning. Otherwise will be set in after scanning starts
        if !self.isScanning {
            return
        }
        
        self.privateSessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureOutput.rectOfInterest = self.capturePreviewLayer.metadataOutputRectConverted(fromLayerRect: scanRect)
        }
        
    }
    
    public func setPreferredAutoFocusRangeRestriction(preferredAutoFocusRangeRestriction: AVCaptureDevice.AutoFocusRangeRestriction) {
        if self.preferredAutoFocusRangeRestriction == preferredAutoFocusRangeRestriction {
            return
        }
        
        self.preferredAutoFocusRangeRestriction = preferredAutoFocusRangeRestriction
        
        if (self.currentCaptureDeviceInput == nil) {
            // the setting will be picked up once a new session incl. device input is created
            return
        }
        
        self.updateFocusPreferencesOfDevice(self.currentCaptureDeviceInput.device, reset: false)
    }
    
    
    // MARK: - Helper Methods
    
    public func rectOfInterest(from scanRect: CGRect) -> CGRect {
        let rect: CGRect
        if !self.scanRect.isEmpty {
            rect = self.capturePreviewLayer.metadataOutputRectConverted(fromLayerRect: self.scanRect)
        } else {
            rect = CGRect(x: 0, y: 0, width: 1, height: 1) // Default rectOfInterest for AVCaptureMetadataOutput
        }
        return rect
    }
}


// MARK: - AVCaptureMetadataOutputObjects Delegate

extension MTBBarcodeScanner: AVCaptureMetadataOutputObjectsDelegate {

    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        let codes = metadataObjects.compactMap { self.capturePreviewLayer.transformedMetadataObject(for: $0) as? AVMetadataMachineReadableCodeObject }
        
        self.delegate?.barcodeScanner(didRecognize: codes)
    }
    
}


// MARK: - AVCapturePhotoCaptureDelegate

extension MTBBarcodeScanner: AVCapturePhotoCaptureDelegate {
    
    @available(iOS 11.0, *)
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
            let data = photo.fileDataRepresentation(),
            let image = UIImage(data: data) else {
                delegate?.barcodeScanner(failedToCaptureStillImageWith: error ?? MTBBarcodeScannerError.StillImageCaptureError.imageCreationFailed)
                return
        }
        delegate?.barcodeScanner(didCapture: image)
    }

    @available(iOS 10.0, *)
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        self.processCapturedStillImage(sampleBuffer: photoSampleBuffer, error: error)
    }

}
