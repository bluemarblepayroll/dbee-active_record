# frozen_string_literal: true

#
# Copyright (c) 2019-present, Blue Marble Payroll, LLC
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

SUPPORTED_ACTIVE_RECORD_VERSIONS = %w[5 6].freeze
ACTIVE_RECORD_VERSION_ENV_KEY = 'AR_VERSION'

task :spec_all_active_record_versions do
  SUPPORTED_ACTIVE_RECORD_VERSIONS.each do |ar_version|
    puts "\nRunning specs under Active Record version #{ar_version}"

    # Note that rspec can not be invoked directly through the Rake::Task API
    # as Rake is smart enough to only run tasks once. However, in this case we
    # do want to do the same thing multiple times just under a different
    # environment.
    # Rake::Task['spec'].invoke

    # The other advantage of the sh approach is that the ENV hash does not have
    # to be mutated in this process.
    sh "#{ACTIVE_RECORD_VERSION_ENV_KEY}=#{ar_version} rspec"
  end
end

task default: %i[rubocop spec_all_active_record_versions]
