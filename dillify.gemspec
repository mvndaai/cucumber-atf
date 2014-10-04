# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dillify/version'

Gem::Specification.new do |spec|
  spec.name          = "dillify"
  spec.version       = Dillify::VERSION
  spec.authors       = ["Jason Mavandi"]
  spec.email         = ["mvndaai@gmail.com"]
  spec.description   = %q{Failure parser for cucumber out files}
  spec.summary       = %q{Displays cucumber failing scenarios in order of most failures}
  spec.homepage      = "https://github.com/mvndaai/dillify"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "cucumber"
  spec.add_dependency "bundler", "~> 1.3"

  spec.add_development_dependency "rake"
end
