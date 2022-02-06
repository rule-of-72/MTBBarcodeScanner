Pod::Spec.new do |s|
  s.name             = "MTBBarcodeScanner2"
  s.version          = "5.0.13"
  s.summary          = "A lightweight, easy-to-use barcode scanning library for iOS 8+."
  s.homepage         = "https://github.com/grevolution/MTBBarcodeScanner"
  s.license          = 'MIT'
  s.author           = { "Shan Haq" => "g@grevolution.me" }
  s.source           = { :git => "https://github.com/grevolution/MTBBarcodeScanner.git", :tag => s.version.to_s }

  s.platform              = :ios, '8.0'
  s.ios.deployment_target = '8.0'
  s.requires_arc          = true

  s.source_files = 'Classes/ios/**/*.{h,m}'
  s.frameworks = 'AVFoundation', 'QuartzCore'
end
