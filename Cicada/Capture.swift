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
public protocol CaptureDelegate {
    
    /// Receives a capture object when one or more codes are detected
    func capture(_ capture: Capture, didReceive result: Result<CaptureObject, CicadaError>)
    
    /// Defines the area of the preview view where codes are detected
    func scanArea(in capture: Capture) -> CGRect
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

/// Represents the operating mode
public enum Mode {
    
    /// Return all codes until stopped
    case continuous
    
    /// Return the first code found
    case once
    
    /// Return each code found once
    case onceUnique
}

/// The core capture class that interacts with the underlying AVFoundation libraries
@available(iOS 13.0, *)
public class Capture: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    
    typealias ResponseEmitter = (CaptureObject) -> Void
    
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
    public let metadataObjectTypes: [AVMetadataObject.ObjectType]
    
    /// Provides the parent layer to display the video preview
    private var previewView: UIView!
    
    /// Signals capture events using haptic device feedback
    private var hapticFeedbackGenerator: HapticFeedbackGenerator?
    
    /// The current operating mode of the camera instance
    public private(set) var mode: Mode
    
    /// Automatically turn on the flashlight when the capture session begins
    public private(set) var autoShowTorch: Bool
    
    /// The current haptic feedback mode
    public private(set) var hapticStyle: HapticStyle?
    
    private var discoveredCodes: [String] = []
    
    private var responseTimeInterval = 0.2
    
    public private(set) var lastCaptureDate: Date? = nil
    
    private var responseEmitter: ResponseEmitter!
    
    /// An object that acts as the delegate for the capture session
    public var delegate: CaptureDelegate? = nil {
        didSet {
            responseHandler = { result in
                self.delegate?.capture(self, didReceive: result)
            }
            scanArea = {
                return self.delegate?.scanArea(in: self)
            }
        }
    }
    
    /// Internal response completion block
    private var responseHandler: ((Result<CaptureObject, CicadaError>) -> Void)? = nil
    
    /// Returns `true` if the capture is active and scanning,  otherwise `false`
    public private(set) lazy var isCaptureRunning: Bool = {
        self.captureSession?.isRunning == true
    }()
    
    /// Completion block that fires when the capture is started
    public var didBeginCapture: (() -> Void)? = nil
    
    /// Defines the area of the preview view where codes are detected
    public var scanArea: (() -> CGRect?)? = nil
    
    public init(
        types: [AVMetadataObject.ObjectType],
        mode: Mode = .once,
        autoTorch: Bool = false,
        haptic: HapticStyle? = nil
    ) {
        self.metadataObjectTypes = types
        self.mode = mode
        self.autoShowTorch = autoTorch
        self.hapticStyle = haptic
        
        if let hapticStyle {
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
            let deviceInput = try AVCaptureDeviceInput(device: device)
            
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
        self.responseEmitter = makeResponseEmitter(for: mode)
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
    ///   - completion: The completion block for the capture result
    public func start(preview: UIView, completion: ((Result<CaptureObject, CicadaError>) -> Void)? = nil) {
        self.responseHandler = completion
        
        preview.backgroundColor = .black // implement custom gradient?
        
        #if targetEnvironment(simulator)
        print("Camera is not available for the simulator")
        #else
        checkCameraAuthorization { [self] granted in
            guard granted else {
                responseHandler?(.failure(.notAuthorized))
                return
            }
            startCapture(preview: preview)
        }
        #endif
    }
    
    private func startCapture(preview: UIView) {
        guard let device = findDeviceCamera() else {
            responseHandler?(.failure(.cameraNotFound))
            return
        }
        captureDevice = device
        
        do {
            let session = try configureSession(device: captureDevice!)
            captureSession = session
        } catch {
            responseHandler?(.failure(error.cicadaError()))
            return
        }
        
        previewView = preview
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = previewView.layer.bounds
        
        capturePreviewLayer = previewLayer
        previewView.layer.insertSublayer(capturePreviewLayer!, at: 0)
        
        addOrientationDidChangeObserver()
        
        let scanRect = self.scanArea?()
        
        if mode != .continuous {
            hapticFeedbackGenerator?.prepare()
        }
        
        if !captureSession!.isRunning {
            DispatchQueue.global(qos: .userInteractive).async { [self] in
                captureSession!.startRunning()
                
                didBeginCapture?()
                
                if let scanRect {
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
        capturePreviewLayer?.removeFromSuperlayer()
        
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
    /// When capture mode is set to `.once` or `.onceUnique`,  this capture session
    /// will clear any previously discovered objects and begin returning new codes.
    ///
    public func restart() {
        lastCaptureDate = nil
        discoveredCodes = []
    }
    
    /// Returns a result emitter block for the capture mode
    ///
    /// - Parameter mode: The current capture mode to emit for
    /// - Returns: An emit function block
    private func makeResponseEmitter(for mode: Mode) -> ResponseEmitter {
        switch mode {
            
        case .once:
            return { [self] captureObject in
                if lastCaptureDate != nil { return }
                
                hapticFeedbackGenerator?.prepare()
                
                discoveredCodes.append(captureObject.stringValue)
                lastCaptureDate = Date()
                responseHandler?(.success(captureObject))
                
                hapticFeedbackGenerator?.feedbackOccured()
            }
            
        case .onceUnique:
            return { [self] captureObject in
                if discoveredCodes.contains(captureObject.stringValue) { return }
                
                hapticFeedbackGenerator?.prepare()
                
                discoveredCodes.append(captureObject.stringValue)
                lastCaptureDate = Date()
                responseHandler?(.success(captureObject))
                
                hapticFeedbackGenerator?.feedbackOccured()
            }
            
        case .continuous:
            return { [self] captureObject in
                if let lastCaptureDate, Date().timeIntervalSince(lastCaptureDate) < responseTimeInterval {
                    return
                }
                if !discoveredCodes.contains(captureObject.stringValue) {
                    discoveredCodes.append(captureObject.stringValue)
                }
                responseHandler?(.success(captureObject))
            }
        }
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
        guard let machineReadableObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = machineReadableObject.stringValue else {
            return
        }
        responseEmitter(CaptureObject(stringValue: stringValue, object: machineReadableObject))
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

// MARK: Orientation - iOS 16 and lower

extension Capture {
    
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
}
