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

  it 'ancestors! falls back to the model wrapped in a Joinable' do
    query_path = ['ticket_prices'].freeze
    found = subject.ancestors!(query_path)
    expect(found.size).to eq 1

    path, joinable = found.first
    expect(path).to eq query_path
    expect(joinable).to be_a(Dbee::Providers::ActiveRecordProvider::Joinable)
    expect(joinable.name).to eq 'ticket_prices'
  end

  it 'allows for derived models to be appended and returned' do
    derived_joinable = Dbee::Providers::ActiveRecordProvider::Joinable.new(
      name: 'subquery',
      parent_model: 'ticket_prices',
      arel: nil,
      constraints: nil
    )
    subject.append!(derived_joinable)
    subquery_path = %w[ticket_prices subquery].freeze
    query_path = [['ticket_prices'].freeze, subquery_path].freeze

    # found = subject.ancestors!(query_path)
    found = subject.ancestors!(subquery_path)
    expect(found.keys).to eq query_path

    joinable = found[subquery_path]
    expect(joinable).to be_a(Dbee::Providers::ActiveRecordProvider::Joinable)
    expect(joinable.name).to eq 'subquery'
  end

  it 'allows for derived models to be appended to the root model'

  it 'allows for derived models to be appended far down the tree'
end
