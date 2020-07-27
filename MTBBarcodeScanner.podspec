Pod::Spec.new do |s|
  s.name             = "MTBBarcodeScanner"
  s.version          = "5.0.11"
  s.summary          = "A lightweight, easy-to-use barcode scanning library for iOS 8+."
  s.homepage         = "https://github.com/mikebuss/MTBBarcodeScanner"
  s.license          = 'MIT'
  s.author           = { "Mike Buss" => "mike@mikebuss.com" }
  s.source           = { :git => "https://github.com/SwiftySam/MTBBarcodeScanner.git", :tag => s.version.to_s }

  s.platform              = :ios, '8.0'
  s.ios.deployment_target = '8.0'
  s.requires_arc          = true
  s.frameworks = 'AVFoundation', 'QuartzCore'
  
  s.default_subspec = 'ObjC'
  s.swift_versions = ['5.1','5.2']
  
  s.subspec 'ObjC' do |ss|
    ss.ios.deployment_target = '8.0'
    ss.source_files = 'Classes/Objc/ios/**/*.{h,m}'
  end
  
  s.subspec 'Swift' do |ss|
    ss.ios.deployment_target = '8.0'
    ss.source_files = 'Classes/Swift/ios/**/*.{swift}'
  end
end
