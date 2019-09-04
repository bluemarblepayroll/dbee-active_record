# frozen_string_literal: true

require './lib/dbee/providers/active_record_provider/version'

Gem::Specification.new do |s|
  s.name        = 'dbee-active_record'
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

  s.required_ruby_version = '>= 2.4.6'

  ar_version = ENV['AR_VERSION'] || ''

  activerecord_version =
    case ar_version
    when '6'
      ['>=6.0.0', '<7']
    when '5'
      ['>=5.2.1', '<6']
    else
      ['>=5.2.1', '<7']
    end

  s.add_dependency('activerecord', activerecord_version)
  s.add_dependency('dbee', '~>2')

  s.add_development_dependency('guard-rspec', '~>4.7')
  s.add_development_dependency('mysql2', '~>0.5')
  s.add_development_dependency('pry', '~>0')
  s.add_development_dependency('rake', '~> 12')
  s.add_development_dependency('rspec', '~> 3.8')
  s.add_development_dependency('rubocop', '~>0.74.0')
  s.add_development_dependency('simplecov', '~>0.17.0')
  s.add_development_dependency('simplecov-console', '~>0.5.0')
  s.add_development_dependency('sqlite3', '~>1')
end
