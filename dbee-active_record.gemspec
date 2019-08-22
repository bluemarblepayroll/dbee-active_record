# frozen_string_literal: true

require './lib/dbee/providers/active_record_provider/version'

Gem::Specification.new do |s|
  s.name        = 'dbee'
  s.version     = Dbee::Providers::ActiveRecordProvider::VERSION
  s.summary     = 'Plugs in ActiveRecord so Dbee can use Arel for SQL generation.'

  s.description = <<-DESCRIPTION
    By default Dbee ships with no underlying SQL generator.  This library will plug in ActiveRecord into Dbee and Dbee will use it for SQL generation.
  DESCRIPTION

  s.authors     = ['Matthew Ruggio']
  s.email       = ['mruggio@bluemarblepayroll.com']
  s.files       = `git ls-files`.split("\n")
  s.test_files  = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.homepage    = 'https://github.com/bluemarblepayroll/dbee-active_record'
  s.license     = 'MIT'

  s.required_ruby_version = '>= 2.3.8'

  s.add_development_dependency('guard-rspec', '~>4.7')
  s.add_development_dependency('pry', '~>0')
  s.add_development_dependency('rspec', '~> 3.8')
  s.add_development_dependency('rubocop', '~>0.63.1')
  s.add_development_dependency('simplecov', '~>0.17.0')
  s.add_development_dependency('simplecov-console', '~>0.4.2')
end
