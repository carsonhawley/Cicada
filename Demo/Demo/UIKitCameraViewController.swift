//
//  UIKitCameraViewController.swift
//  Demo
//
//  Created by Blue Bonsai on 9/24/23.
//

import UIKit
import Cicada

class UIKitCameraViewController: UIViewController {
    
    @IBOutlet private var previewView: UIView!
    @IBOutlet private var viewfinder: UIView!
    @IBOutlet private var torchButton: UIButton!
    @IBOutlet private var resetButton: UIButton!
    
    private let capture = Capture(types: [.qr], mode: .onceUnique, haptic: .medium)
    private var showTorch = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        torchButton.tintColor = .gray
        
        capture.scanArea = { self.viewfinder.frame }
        capture.start(preview: previewView) { result in
            switch result {
            case .success(let code):
                print("Capture result: \(code.stringValue)")
            
            case .failure(let error):
                print("An error occured: \(error.localizedDescription)")
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        capture.stop()
        
        showTorch = false
        torchButton.tintColor = .gray
    }
    
    override func viewDidLayoutSubviews() {
        capture.autoResizePreview()
    }
    
    // MARK: Button Actions
    
    @IBAction func onTappedTorchButton(_ sender: Any) {
        showTorch.toggle()
        torchButton.tintColor = showTorch ? nil : .gray
        
        capture.toggleTorch(on: showTorch)
        
        print("Toggle torch \(showTorch ? "on" : "off")")
    }
    
    @IBAction func onTappedResetButton(_ sender: Any) {
        print("Restart camera")
        capture.restart()
    }
}
