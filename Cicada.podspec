Pod::Spec.new do |spec|

  spec.name         = "Cicada"
  spec.version      = "0.2.1"
  spec.summary      = "A tiny but versatile QR scanner written in Swift"
  spec.description  = <<-DESC
                    Cicada is lightweight, drop-in solution for QR or barcode scanning on iOS. Available
                    for both UIKit and SwiftUI.
                   DESC
  spec.homepage     = "https://github.com/carsonhawley/Cicada"
  spec.license      = { :type => "MIT" }
  spec.author       = "Carson Hawley"
  spec.social_media_url = "https://github.com/carsonhawley"
  spec.swift_versions = ["5.0"]
  spec.ios.deployment_target = "13.0"
  spec.source       = { :git => "https://github.com/carsonhawley/Cicada.git", :tag => "#{spec.version}" }
  spec.source_files  = "Cicada/**/*.swift"

end
