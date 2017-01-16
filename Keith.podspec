Pod::Spec.new do |s|
  s.name = 'Keith'
  s.module_name = 'Keith'
  s.version = '1.0.0'
  s.license = { type: 'MIT', file: 'LICENSE' }
  s.summary = 'A media player for iOS written in Swift.'
  s.homepage = 'https://github.com/movile/Keith'
  s.authors = { 'Rafael Alencar' => 'rafael.alencar@movile.com' }
  s.source = { :git => 'https://github.com/movile/Keith.git', :tag => "v#{s.version}" }
  s.ios.deployment_target = '9.2'
  s.source_files = 'Keith/*.swift'
end
