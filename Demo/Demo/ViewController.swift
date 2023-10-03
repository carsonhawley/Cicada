//
//  ViewController.swift
//  Demo
//
//  Created by Carson Hawley on 9/3/23.
//

import UIKit
import Cicada
import SwiftUI

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    // MARK: Button Actions
    
    @IBAction func onTappedUIKitButton(_ sender: Any) {
        guard let cameraViewController = self.storyboard?.instantiateViewController(withIdentifier: "UIKitCameraViewController") as? UIKitCameraViewController else {
            return
        }
        self.present(cameraViewController, animated: true)
    }
    
    @IBAction func onTappedSwiftUIButton(_ sender: Any) {
        let hostingViewController = UIHostingController(rootView: SwiftUICaptureView())
        hostingViewController.view.backgroundColor = .black
        self.present(hostingViewController, animated: true)
    }
}
