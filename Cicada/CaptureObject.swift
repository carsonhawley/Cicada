//
//  CaptureResult.swift
//  Cicada
//
//  Created by Carson Hawley on 9/9/23.
//

import Foundation
import AVFoundation

/// A cicada capture result
public struct CaptureObject {
    
    /// Result data decoded as a string
    public private(set) var stringValue: String
    
    /// The type of object that was detected
    public private(set) var type: AVMetadataObject.ObjectType
    
    /// The corners of the object as they appear on the screen
    public private(set) var corners: [CGPoint]
    
    /// Result data decoded as a url
    public lazy var urlValue: URL? = { URL(string: stringValue) }()
    
    internal init(stringValue: String, object: AVMetadataMachineReadableCodeObject) {
        self.stringValue = stringValue
        self.type = object.type
        self.corners = object.corners
    }
}
