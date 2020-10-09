# frozen_string_literal: true

#
# Copyright (c) 2018-present, Blue Marble Payroll, LLC
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

require 'yaml'
require 'pry'

unless ENV['DISABLE_SIMPLECOV'] == 'true'
  require 'simplecov'
  require 'simplecov-console'

  SimpleCov.formatter = SimpleCov::Formatter::Console
  SimpleCov.start do
    add_filter %r{\A/spec/}
  end
end

require './lib/dbee/providers/active_record_provider'

def fixture_path(*filename)
  File.join('spec', 'fixtures', filename)
end

def yaml_fixture(*filename)
  YAML.safe_load(fixture(*filename))
end

def fixture(*filename)
  File.open(fixture_path(*filename), 'r:bom|utf-8').read
end

def yaml_fixture_files(*directory)
  Dir[File.join('spec', 'fixtures', *directory, '**', '*.yaml')].map do |filename|
    [
      filename,
      yaml_file_read(filename)
    ]
  end.to_h
end

def yaml_file_read(*filename)
  YAML.safe_load(file_read(*filename))
end

def file_read(*filename)
  File.open(File.join(*filename), 'r:bom|utf-8').read
end

def models
  yaml_fixture('models.yaml')
end
