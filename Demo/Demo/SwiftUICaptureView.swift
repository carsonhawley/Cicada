//
//  SwiftUICaptureView.swift
//  Demo
//
//  Created by Blue Bonsai on 9/24/23.
//

import SwiftUI
import Cicada

struct SwiftUICaptureView: View {
    var body: some View {
        CaptureView(mode: .once) { result in
            switch result {
            case .success(let codes):
                codes.forEach { result in
                    print("Capture result: \(result.stringValue)")
                }
            case .failure(let error):
                print("An error occured: \(error.localizedDescription)")
            }
        }
        .ignoresSafeArea()
        .animation(nil)
    }
}

#Preview {
    SwiftUICaptureView()
}
