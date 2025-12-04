//
//  CaptureView.swift
//  Cicada
//
//  Created by Carson Hawley on 9/2/23.
//

#if os(iOS)
import SwiftUI
import AVFoundation

public struct CaptureView: UIViewControllerRepresentable {
    
    internal let metadataObjectTypes: [AVMetadataObject.ObjectType]
    internal let mode: Mode
    internal let autoShowTorch: Bool
    internal let hapticStyle: HapticStyle?
    internal let completion: (Result<CaptureObject, CicadaError>) -> Void
    
    public init(
        types: [AVMetadataObject.ObjectType] = [.qr],
        mode: Mode = .once,
        autoTorch: Bool = false,
        haptic: HapticStyle? = nil,
        completion: @escaping (Result<CaptureObject, CicadaError>) -> Void
    ) {
        self.metadataObjectTypes = types
        self.mode = mode
        self.autoShowTorch = autoTorch
        self.hapticStyle = haptic
        self.completion = completion
    }
    
    public typealias UIViewControllerType = CaptureViewController
    
    public func makeUIViewController(context: Context) -> CaptureViewController {
        return CaptureViewController(parentView: self)
    }
    
    public func updateUIViewController(_ uiViewController: CaptureViewController, context: Context) {
       
    }
}

public class CaptureViewController: UIViewController {
    
    private var parentView: CaptureView!
    private var capture: Capture!
    
    private let previewView = UIView()
    
    init(parentView: CaptureView) {
        self.parentView = parentView
        self.capture = Capture(
            types: parentView.metadataObjectTypes,
            mode: parentView.mode,
            autoTorch: parentView.autoShowTorch,
            haptic: parentView.hapticStyle
        )
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
    
        self.view.addSubview(previewView)
        
        previewView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: self.view.topAnchor),
            previewView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            previewView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
        ])
        
        capture.start(preview: previewView, completion: parentView.completion)
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        capture.autoResizePreview()
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(true)
        capture.stop()
    }
}
#endif
