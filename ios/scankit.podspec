Pod::Spec.new do |s|
  s.name             = 'scankit'
  s.version          = '0.0.1'
  s.summary          = 'A modern, lean barcode and QR code scanner for Flutter.'
  s.description      = <<-DESC
A modern barcode scanner using VisionKit (iOS 16+) with AVFoundation fallback.
                       DESC
  s.homepage         = 'https://github.com/example/scankit'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'ScanKit' => 'scankit@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }

  s.resource_bundles = {'scankit_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
