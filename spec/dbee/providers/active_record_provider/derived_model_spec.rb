# frozen_string_literal: true

#
# Copyright (c) 2019-present, Blue Marble Payroll, LLC
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

require 'spec_helper'
require 'db_helper'

describe Dbee::Providers::ActiveRecordProvider::DerivedModel do
  let(:model) { Dbee::Model.make(models['Theaters, Members, and Movies']) }
  let(:joinable_builder) do
    Dbee::Providers::ActiveRecordProvider::JoinableBuilder.new(
      Dbee::Providers::ActiveRecordProvider::SafeAliasMaker.new
    )
  end
  let(:subject) { described_class.new(model, joinable_builder) }

  specify 'ancestors! falls back to the model wrapped in a Joinable' do
    query_path = ['ticket_prices'].freeze
    found = subject.ancestors!(query_path)
    expect(found.size).to eq 1

    path, joinable = found.first
    expect(path).to eq query_path
    expect(joinable).to be_a(Dbee::Providers::ActiveRecordProvider::Joinable)
    expect(joinable.name).to eq 'ticket_prices'
  end

  describe 'appending a derived model' do
    SCENARIOS = [
      {
        name: 'allows for derived models to be appended and returned',
        parent_model: 'theaters.ticket_prices',
        subquery_path: %w[ticket_prices subquery].freeze,
        query_path: [
          ['ticket_prices'].freeze,
          %w[ticket_prices subquery].freeze
        ]
      },
      {
        name: 'allows for derived models to be appended to the root model',
        parent_model: 'theaters',
        subquery_path: %w[subquery].freeze,
        query_path: [%w[subquery].freeze].freeze
      },
      {
        name: 'allows for derived models to be appended far down the tree',
        parent_model: 'theaters.members.demos',
        subquery_path: %w[members demos subquery].freeze,
        query_path: [
          %w[members].freeze,
          %w[members demos].freeze,
          %w[members demos subquery].freeze
        ].freeze
      }
    ].freeze

    SCENARIOS.each do |scenario|
      it scenario[:name] do
        derived_joinable = Dbee::Providers::ActiveRecordProvider::Joinable.new(
          name: 'subquery',
          parent_model: scenario[:parent_model],
          arel: nil,
          constraints: nil
        )
        subject.append!(derived_joinable)
        subquery_path = scenario[:subquery_path]
        query_path = scenario[:query_path]

        found = subject.ancestors!(subquery_path)
        expect(found.keys).to eq query_path

        joinable = found[subquery_path]
        expect(joinable).to be_a(Dbee::Providers::ActiveRecordProvider::Joinable)
        expect(joinable.name).to eq 'subquery'
      end
    end
  end
end
