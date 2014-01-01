# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'treegen/version'

Gem::Specification.new do |spec|
  spec.name          = "treegen"
  spec.version       = Treegen::VERSION
  spec.authors       = ["david karapetyan"]
  spec.email         = ["dkarapetyan@scriptcrafty.com"]
  spec.description   = "Simple DSL for tree generation."
  spec.summary       = "Takes a description of terminal and non-terminal nodes and gives back various incarnations of trees."
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "pry"
end
