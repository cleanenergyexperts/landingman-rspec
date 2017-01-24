# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "landingman-rspec"
  s.version     = "0.0.15"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Matt Snider"]
  s.email       = ["matt@cleanenergyexperts.com"]
  s.homepage    = "https://www.cleanenergyexperts.com"
  s.summary     = %q{Adds RSPEC helpers for testing web pages}
  # s.description = %q{A longer description of your extension}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  
  # The version of middleman-core your extension depends on
  s.add_runtime_dependency("middleman-core", [">= 4.1.1"])
  
  # Additional dependencies
  s.add_runtime_dependency('rake', ['~> 11.1', '>= 11.1.2'])
  s.add_runtime_dependency('rspec', ['~> 3.4'])
  s.add_runtime_dependency('capybara', ['~> 2.5'])
  s.add_runtime_dependency('capybara-webkit', ['~> 1.10'])
  s.add_runtime_dependency('nokogiri', ['~> 1.6'])
end
