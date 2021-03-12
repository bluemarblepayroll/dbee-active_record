# frozen_string_literal: true

#
# Copyright (c) 2019-present, Blue Marble Payroll, LLC
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

require 'spec_helper'

describe Dbee::Providers::ActiveRecordProvider::DerivedSchema do
  let(:dbee_schema) { Dbee::Schema.new(models['Theaters, Members, and Movies']) }
  let(:theaters_model) { dbee_schema.model_for_name!(:theaters) }
  let(:theaters_joinable) do
    Dbee::Providers::ActiveRecordProvider::Joinable.new(theaters_model)
  end
  let(:ticket_prices_model) { dbee_schema.model_for_name!(:ticket_prices) }
  let(:ticket_prices_joinable) do
    Dbee::Providers::ActiveRecordProvider::Joinable.new(ticket_prices_model)
  end
  let(:subject) { described_class.new(dbee_schema) }

  describe '#expand_query_path' do
    it 'delegates to the Dbee::Schema and accepts joinables' do
      key_path = Dbee::KeyPath.new('id')
      mock_dbee_schema = instance_double(Dbee::Schema)
      expect(mock_dbee_schema)
        .to receive(:expand_query_path)
        .with(theaters_model, key_path)
        .and_return([])

      described_class.new(mock_dbee_schema).expand_query_path(theaters_joinable, key_path)
    end

    it 'returns relationships and joinables' do
      expected_query_path = [
        [theaters_model.relationship_for_name('ticket_prices'), ticket_prices_joinable]
      ]
      found_query_path = subject.expand_query_path(
        theaters_joinable, Dbee::KeyPath.new('ticket_prices.id')
      )
      expect(found_query_path).to eq expected_query_path
    end
  end

  describe '#joinable_for_model_name' do
    it 'the joinable associated with a model' do
      expect(subject.joinable_for_model_name!(theaters_model.name)).to eq theaters_joinable
    end
  end

  describe 'dynamically appending subqueries' do
    let(:subquery_spec) do
      {
        name: 'effective_ticket_prices',
        from: 'ticket_prices',
        relationships_from: {
          ticket_prices: {
            constraints: [
              { name: 'theater_id', parent: 'theater_id' },
              { name: 'effective_date', parent: 'effective_date' }
            ]
          }
        },
        fields: [
          { key_path: 'theater_id' },
          { key_path: 'effective_date', aggregator: 'max' }
        ],
        filters: [
          { key_path: 'effective_date', type: 'less_than_or_equal_to', value: '2020-01-01' }
        ]
      }
    end

    it 'creates a derived model wrapped in a joinable for a subquery' do
      subject.append_subquery(Dbee::Query.make(subquery_spec))
      expected_model = Dbee::Model::Derived.make(
        name: 'effective_ticket_prices',
        query: subquery_spec
      )
      expected_joinable = Dbee::Providers::ActiveRecordProvider::Joinable.new(expected_model)

      expect(subject.joinable_for_model_name!('effective_ticket_prices')).to eq expected_joinable
    end

    it 'raises an ArgumentError if the subquery name is equal to an existing model name' do
      subquery = Dbee::Query::Sub.make(name: 'theaters')

      expect { subject.append_subquery(subquery) }.to raise_error(
        ArgumentError, "a model named 'theaters' already exists"
      )
    end

    it 'attaches the derived model to the schema based on the subquery\'s relationships_from' do
      query_path = Dbee::KeyPath.new('effective_ticket_prices.id')
      subquery = Dbee::Query.make(subquery_spec)

      expected_subquery_relationship = Dbee::Model::Relationships.make(
        name: 'effective_ticket_prices',
        constraints: subquery.relationships_from['ticket_prices'].constraints
      )

      subject.append_subquery(subquery)

      expected_query_path = [
        [
          expected_subquery_relationship,
          subject.joinable_for_model_name!('effective_ticket_prices')
        ]
      ]

      found_query_path = subject.expand_query_path(ticket_prices_joinable, query_path)
      expect(found_query_path).to eq expected_query_path
    end
  end
end
