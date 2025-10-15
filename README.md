# Cicada

A tiny but versatile QR scanner written in Swift

![iOS Platform](https://img.shields.io/badge/iOS-13.0+-blue)
![Swift Language](https://img.shields.io/badge/Swift-5.0-orange)
![MIT License](https://img.shields.io/badge/License-MIT-violet)

## Installation

### Cocoapods

Add the following package to your Podfile

```ruby
platform :ios, '13.0'
use_frameworks!

target 'MyApp' do
  pod 'Cicada', '~> 0.1.0'
end
```

## Quickstart

Cicada is designed to be as hands-off as possible. If you want a quick n' dirty example:

```swift
import Cicada

class ExampleViewController: UIViewController {
    
    @IBOutlet private var previewView: UIView!
    
    private let capture = Capture(types: [.qr], mode: .once)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        capture.start(preview: previewView) { result in
            switch result {
            case .success(let codes):
                print("capture result: \(codes.first!.stringValue)")
            case .failure(let error):
                print("do something with error")
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        capture.stop()
    }
}
```

And if delegates are more your style:

```swift
class ExampleViewController: UIViewController, CicadaCaptureDelegate {
    
    func capture(_ capture: Capture, didReceive result: Result) {
        // handle the result here
    }
}
```

Remember to include [NSCameraUsageDescription](https://developer.apple.com/documentation/avfoundation/capture_setup/requesting_authorization_to_capture_and_save_media) in your `info.plist` before attempting to access the camera. 

Cicada supports several different capture behaviors
- `.once` - Returns a single code. This is the default case.
- `.onceUnique` - Scans for many codes and returns each unique code once 
- `.continuous` - Returns all codes until `capture.stop()` is called. Codes are streamed at a 0.2 second interval to preserve battery life

### Scan Area

You can limit the area of the screen where codes are detected. The most common example is scanning within a viewfinder frame:

```swift
capture.scanArea = { self.viewfinder.frame }
```

### Show the Torch

Toggle the torch manually by calling:

```swift
capture.toggleTorch(on: true)
```

...or allow the system to enable the torch automatically as needed:

```swift
let capture = Capture(types: [.qr], autoTorch: true)
```

### Haptic Feedback

You can choose to vibrate the device when a code is detected. The list of available styles from least to most impactful are:

```swift
HapticStyle.light
HapticStyle.medium
HapticStyle.heavy
HapticStyle.double 
```

All haptic feedback styles are ignored for `.continuous` mode

### Capture Preview Dim Strength

Dims the capture session preview after a code is scanned. 

```
DimStrength.light
DimStrength.medium
DimStrength.heavy
DimStrength.custom(Float)
```

DimStrength only applies to `.once` mode.

### Camera Orientation

If your app supports multiple orientations, then you must update the capture preview to reflect those changes:

```swift
override func viewDidLayoutSubviews() {
    capture.autoResizePreview()
}
```

Or if your parent is UIView:

```swift
override func layoutSubviews() {
    super.layoutSubviews()
    capture.autoResizePreview()
}
```

## SwiftUI

Cicada also provides its own SwiftUI view

```swift
struct ExampleView: View {

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
    }
}
```

## License

Cicada is available under the MIT license. See the [LICENSE](LICENSE.md) file for more info. 

