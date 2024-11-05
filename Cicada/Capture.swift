//
//  Capture.swift
//  Cicada
//
//  Created by Carson Hawley on 8/30/23.
//

import UIKit
import Foundation
import AVFoundation

/// Methods for receiving capture results and manipulating the scan area
public protocol CicadaCaptureDelegate {
    
    /// Receives a capture result when one or more codes are detected
    func capture(_ capture: Capture, didReceive result: Result)
    
    /// Defines the area of the preview view where codes are detected
    func scanArea(in capture: Capture) -> CGRect
}

/// Represents a capture response
public enum Result {
    /// Success case with one or more results
    case success([CaptureResult])
    
    /// Failure case with the error that interrupted the task
    case failure(CicadaError)
}

/// Represents all errors returned by the framework
public enum CicadaError: Error {
    
    /// The camera session is not in the correct state to receive input
    case invalidInput
    
    /// The camera is temporarily unable to output data or the device may not
    /// support the requested output types
    case invalidOutput
    
    /// A suitable camera could not be found
    case cameraNotFound
    
    /// The user did not grant authorization to access the camera
    case notAuthorized
    
    /// The framework encountered an unexpected error
    /// - Parameter reason: A description of the underlying error
    case unknownFailure(_ reason: String)
}

/// The core capture class that interacts with the underlying AVFoundation libraries
@available(iOS 13.0, *)
public class Capture: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    
    /// Represents the operating mode
    public enum Mode {
        
        /// Return all codes until stopped
        case continuous
        
        /// Return the first code found
        case once
        
        /// Return each code found once
        case onceUnique
    }
    
    /// Acceptable camera types for scanning. These are evaluated in order during  an `AVCaptureDevice.DiscoverySession`
    private let deviceTypes: [AVCaptureDevice.DeviceType] = [
        .builtInWideAngleCamera,
        .builtInUltraWideCamera,
        .builtInTripleCamera,
        .builtInDualCamera,
        .builtInDualWideCamera,
        .builtInTelephotoCamera,
    ]
    
    /// Represents physical camera hardware
    private var captureDevice: AVCaptureDevice?
    
    /// Configures capture behavior and coordinates inputs/outputs
    private var captureSession: AVCaptureSession?
   
    /// Capture output for a streamed capture session
    private var captureMetadataOutput: AVCaptureMetadataOutput?
    
    /// Animation layer that displays the video preview
    private var capturePreviewLayer: AVCaptureVideoPreviewLayer?
    
    /// Types of metadata that may be returned
    private let metadataObjectTypes: [AVMetadataObject.ObjectType]
    
    /// Provides the parent layer to display the video preview
    private var previewView: UIView!
    
    /// Signals capture events using haptic device feedback
    private var hapticFeedbackGenerator: HapticFeedbackGenerator?
    
    private var mode: Mode
    
    private var autoShowTorch: Bool
    
    private var hapticStyle: HapticStyle?
    
    private var discoveredCodes: [String] = []
    
    private var didCaptureOnce = false
    
    private var resultTimeInterval = 0.2
    
    private var lastCaptureDate = Date(timeIntervalSince1970: 0)
    
    /// An object that acts as the delegate for the capture session
    public var delegate: CicadaCaptureDelegate? = nil {
        didSet {
            resultHandler = { result in
                self.delegate?.capture(self, didReceive: result)
            }
            scanArea = {
                return self.delegate?.scanArea(in: self)
            }
        }
    }
    
    /// Internal result block
    private var resultHandler: ((Result) -> Void)? = nil
    
    /// Returns `true` if the capture is active and scanning,  otherwise `false`
    public private(set) lazy var isCaptureRunning: Bool = {
        self.captureSession?.isRunning == true
    }()
    
    /// Result block that fires when the capture is started
    public var didBeginCapture: (() -> Void)? = nil
    
    /// Defines the area of the preview view where codes are detected
    public var scanArea: (() -> CGRect?)? = nil
    
    public init(
        types: [AVMetadataObject.ObjectType] = [.qr],
        mode: Mode = .once,
        autoTorch: Bool = false,
        haptic: HapticStyle? = nil
    ) {
        self.metadataObjectTypes = types
        self.mode = mode
        self.autoShowTorch = autoTorch
        self.hapticStyle = haptic
        
        if let hapticStyle = hapticStyle {
            self.hapticFeedbackGenerator = HapticFeedbackGenerator(style: hapticStyle)
        }
    }
    
    /// Ensures device output can produce the requested metadata types
    private func validateTypes(output: AVCaptureMetadataOutput, requestedTypes: [AVMetadataObject.ObjectType]) -> Bool {
        let availableTypes = NSSet(array: output.availableMetadataObjectTypes)
        return NSSet(array: requestedTypes).isSubset(of: availableTypes as! Set<AnyHashable>)
    }
    
    private func configureSession(device: AVCaptureDevice) throws -> AVCaptureSession {
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        do {
            let deviceInput =  try AVCaptureDeviceInput(device: device)
            
            guard session.canAddInput(deviceInput) else {
                throw CicadaError.invalidInput
            }
            session.addInput(deviceInput)
        } catch {
            throw CicadaError.invalidInput
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        guard session.canAddOutput(metadataOutput) else {
            throw CicadaError.invalidOutput
        }
        session.addOutput(metadataOutput)
        
        session.commitConfiguration()
        
        if !validateTypes(output: metadataOutput, requestedTypes: metadataObjectTypes) {
            throw CicadaError.invalidOutput
        }
        
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main) // TODO: background queue
        metadataOutput.metadataObjectTypes = metadataObjectTypes // May throw NSException
        self.captureMetadataOutput = metadataOutput
        
        return session
    }
    
    private func findDeviceCamera() -> AVCaptureDevice? {
        let devicePosition: AVCaptureDevice.Position = .back
        guard 
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: devicePosition)
        else {
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: deviceTypes,
                mediaType: .video,
                position: devicePosition)
            let devices = discoverySession.devices
            
            if devices.count == 0 {
                return nil
            }
            return devices.first
        }
        return device
    }
    
    /// Checks if the user has authorized the use of the camera
    ///
    /// Note: It is not necessary to call this function directly as `start()` will automatically
    /// request camera access if needed.
    ///
    /// - Parameter completion: The completion block
    public func checkCameraAuthorization(_ completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            fallthrough
        @unknown default:
            completion(false)
        }
    }
    
    /// Displays the camera preview and begins scanning for codes
    ///
    /// - Parameters:
    ///   - preview: The view to attach the live camera preview layer to
    ///   - completion: The completion block for capture results
    public func start(preview: UIView, completion: ((Result) -> Void)? = nil) {
        self.resultHandler = completion
        
        preview.backgroundColor = .black // implement custom gradient?
        
        #if targetEnvironment(simulator)
        print("Camera is not available for the simulator")
        #else
        checkCameraAuthorization { [self] granted in
            guard granted else {
                resultHandler?(.failure(.notAuthorized))
                return
            }
            startCapture(preview: preview)
        }
        #endif
    }
    
    private func startCapture(preview: UIView) {
        guard let device = findDeviceCamera() else {
            resultHandler?(.failure(.cameraNotFound))
            return
        }
        captureDevice = device
        
        do {
            let session = try configureSession(device: captureDevice!)
            captureSession = session
        } catch {
            resultHandler?(.failure(error.cicadaError()))
            return
        }
        
        previewView = preview
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = previewView.layer.bounds
        
        capturePreviewLayer = previewLayer
        previewView.layer.addSublayer(capturePreviewLayer!)
        
        addOrientationDidChangeObserver()
        
        let scanRect = self.scanArea?()
        
        if !captureSession!.isRunning {
            DispatchQueue.global(qos: .userInteractive).async { [self] in
                captureSession!.startRunning()
                
                didBeginCapture?()
                
                if let scanRect = scanRect {
                    self.captureMetadataOutput?.rectOfInterest = previewLayer.metadataOutputRectConverted(fromLayerRect: scanRect)
                }
                
                if autoShowTorch {
                    toggleTorch(on: true)
                }
            }
        } else {
            print("Capture is already in progress")
        }
    }
    
    /// Stops scanning for codes
    ///
    public func stop() {
        // prevent crash when calling stop before start
        if captureSession?.isRunning == true {
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                captureSession?.stopRunning()
                toggleTorch(on: false)
            }
        } else {
            print("Capture is already stopped")
        }
        removeOrientationDidChangeObserver()
    }
    
    /// Restarts the capture session
    ///
    /// When capture mode is set to `[.once, onceUnique]`, this resets any previous results and
    /// tells capture to begin returning new codes
    ///
    public func restart() {
        didCaptureOnce = false
        discoveredCodes = []
    }
    
    /// Resizes the camera preview layer to match layout updates
    ///
    /// We recommend calling this function in `viewDidLayoutSubviews()` or `layoutSubviews()`
    ///
    public func autoResizePreview() {
        capturePreviewLayer?.frame = previewView.layer.bounds
        
        if captureSession?.isRunning == true  {
            if let scanRect = scanArea?() {
                DispatchQueue.global(qos: .userInteractive).async { [self] in
                    if let previewLayer = capturePreviewLayer {
                        captureMetadataOutput?.rectOfInterest = previewLayer.metadataOutputRectConverted(fromLayerRect: scanRect)
                    }
                }
            }
        }
    }
    
    // MARK: AVCaptureMetadataOutputObjectsDelegate
    
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard metadataObjects.count > 0 else {
            return
        }
        
        switch mode {
        case .continuous:
            if Date().timeIntervalSince(lastCaptureDate) < resultTimeInterval { return }
            
            let results = metadataObjects.compactMap { buildResult(from: $0) }
            if results.count > 0 {
                resultHandler?(.success(results))
            }
            lastCaptureDate = Date()
            
        case .once:
            if didCaptureOnce { return }
            hapticFeedbackGenerator?.prepare()
      
            for object in metadataObjects {
                if let result = buildResult(from: object) {
                    resultHandler?(.success([result]))
                    didCaptureOnce = true
                    
                    hapticFeedbackGenerator?.feedbackOccured()
                    break
                }
            }
            
        case .onceUnique:
            if Date().timeIntervalSince(lastCaptureDate) < resultTimeInterval { return }
            hapticFeedbackGenerator?.prepare()
            
            let results = metadataObjects.compactMap { buildResult(from: $0, unique: true) }
            if results.count > 0 {
                resultHandler?(.success(results))
                
                hapticFeedbackGenerator?.feedbackOccured()
            }
            lastCaptureDate = Date()
        }
    }
    
    private func buildResult(from object: AVMetadataObject, unique: Bool = false) -> CaptureResult? {
        guard 
            let machineReadableObject = object as? AVMetadataMachineReadableCodeObject,
            let stringValue = machineReadableObject.stringValue else {
            return nil
        }
        if unique {
            if discoveredCodes.contains(stringValue) { return nil }
            discoveredCodes.append(stringValue)
        }
        return CaptureResult(
            stringValue: stringValue,
            type: machineReadableObject.type,
            corners: machineReadableObject.corners
        )
    }
    
    // MARK: Interface Orientation - iOS 16 and lower
    
    private func addOrientationDidChangeObserver() {
        NotificationCenter.default
            .addObserver(
                self,
                selector: #selector(updateOrientation),
                name: UIDevice.orientationDidChangeNotification,
                object: nil)
    }
    
    private func removeOrientationDidChangeObserver() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIDevice.orientationDidChangeNotification,
            object: nil)
    }
    
    @objc private func updateOrientation() {
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        guard let orientation = windowScene?.interfaceOrientation else { return }
        
        guard let connection = capturePreviewLayer?.connection, connection.isVideoOrientationSupported else { return }
        connection.videoOrientation = getCaptureVideoOrientation(orientation)
    }
    
    private func getCaptureVideoOrientation(_ orientation: UIInterfaceOrientation) -> AVCaptureVideoOrientation {
        switch orientation {
        case .portrait:
            return AVCaptureVideoOrientation.portrait
        case .landscapeLeft:
            return AVCaptureVideoOrientation.landscapeLeft
        case .landscapeRight:
            return AVCaptureVideoOrientation.landscapeRight
        case .portraitUpsideDown:
            return AVCaptureVideoOrientation.portraitUpsideDown
        default:
            return AVCaptureVideoOrientation.portrait
        }
    }
    
    // MARK: Torch Mode
    
    /// Toggles device torch on or off
    ///
    /// You can only call this function after the capture session has begun. For any devices
    /// that do not have a torch, or if the torch is temporarily unavailable, then this function 
    /// does nothing
    ///
    /// - Parameter on: `true` if the torch should be activated
    public func toggleTorch(on: Bool) {
        guard let device = captureDevice else {
            return
        }
        if device.hasTorch && device.isTorchAvailable {
            do {
                try device.lockForConfiguration()
                
                device.torchMode = on ? .on : .off
                
                device.unlockForConfiguration()
            } catch {
                // do nothing
            }
        }
    }
}

internal extension Error {
    
    func cicadaError() -> CicadaError {
        return self as? CicadaError ?? .unknownFailure(self.localizedDescription)
    }
}
