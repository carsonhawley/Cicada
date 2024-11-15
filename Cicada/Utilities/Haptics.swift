//
//  Haptics.swift
//  Cicada
//
//  Created by Blue Bonsai on 11/4/24.
//

import UIKit

/// Represents different types of device haptic styles when playing a vibration
public enum HapticStyle {
    /// Light impact style
    case light
    /// Medium impact style
    case medium
    /// Heavy impact style
    case heavy
    /// Double impact or `success` style
    case double
}

/// Provides a unified interface for different feedback generator subclasses
internal class HapticFeedbackGenerator: NSObject {
    
    private let feedbackGenerator: UIFeedbackGenerator
    
    init(style: HapticStyle) {
        if style == .double {
            feedbackGenerator = UINotificationFeedbackGenerator()
        } else {
            var feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle
            switch style {
            case .heavy:
                feedbackStyle = .heavy
            case .medium:
                feedbackStyle = .medium
            case .light:
                feedbackStyle = .light
            default:
                feedbackStyle = .medium
            }
            feedbackGenerator = UIImpactFeedbackGenerator(style: feedbackStyle)
        }
    }
    
    func prepare() {
        feedbackGenerator.prepare()
    }
    
    func feedbackOccured() {
        if let feedbackGenerator = feedbackGenerator as? UIImpactFeedbackGenerator {
            feedbackGenerator.impactOccurred()
        } else if let feedbackGenerator = feedbackGenerator as? UINotificationFeedbackGenerator {
            feedbackGenerator.notificationOccurred(.success)
        }
    }
}
