$LOAD_PATH.unshift File.expand_path '../lib', __FILE__
require 'stacker/version'

Gem::Specification.new do |s|
  s.name        = 'stacker'
  s.version     = Stacker::VERSION
  s.summary     = 'Easily assemble CloudFormation stacks.'
  s.description = 'Stacker helps you assemple and manage CloudFormation stacks and dependencies.'
  s.license     = 'MIT'

  s.files       = Dir['lib/**/*']
  s.executables = Dir['bin/*'].map{ |f| File.basename(f) }

  s.authors     = ['Cotap, Inc.']
  s.email       = %w[martin@cotap.com evan@cotap.com]
  s.homepage    = 'https://github.com/cotap/stacker'

  s.required_ruby_version = '>= 3.0'

  s.add_dependency 'activesupport', '~> 7.0'
  s.add_dependency 'aws-sdk', '~> 3'
  s.add_dependency 'coderay', '~> 1.1'
  s.add_dependency 'diffy', '~> 3.0'
  s.add_dependency 'indentation', '~> 0.0'
  s.add_dependency 'memoist', '>= 0.16.2'
  s.add_dependency 'rainbow', '~> 3.0'
  s.add_dependency 'thor', '~> 1.0'

  s.add_development_dependency 'rake', '~> 13.0'
  s.add_development_dependency 'rspec', '~> 3.0'
end
