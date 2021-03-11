# frozen_string_literal: true

#
# Copyright (c) 2019-present, Blue Marble Payroll, LLC
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

require 'spec_helper'
require 'db_helper'

describe Dbee::Providers::ActiveRecordProvider::Joinable do
  let(:table_model) do
    Dbee::Model::TableBased.new(
      name: 'table_based_model',
      table: 'table_based_model',
      relationships: { other_model: { constraints: [{ name: 'other_model_id', parent: 'id' }] } },
      partitioners: [{ name: 'type', value: 'foo_type' }]
    )
  end

  it 'forwards relationships, name, and partitioners to the model' do
    subject = described_class.new(table_model)
    expect(subject.name).to eq table_model.name
    expect(subject.relationships.keys).to eq ['other_model']
    expect(subject.partitioners.first.name).to eq 'type'
  end

  describe 'for table based models' do
    it 'returns an Arel::Table' do
      found_arel = described_class.new(table_model).to_arel

      expect(found_arel).to be_a Arel::Table
      expect(found_arel.name).to eq table_model.name
      expect(found_arel.table_alias).to eq ''
    end

    it 'creates an alias based on the join path' do
      found_arel = described_class.new(table_model).to_arel(%w[level1 level2])

      expect(found_arel).to be_a Arel::Table
      expect(found_arel.name).to eq table_model.name
      expect(found_arel.table_alias).to eq 'level1_level2'
    end
  end

  describe 'for derived/subquery based models' do
    let(:query) { Dbee::Query.make(name: 'derived_model') }

    let(:expression_builder_double) do
      instance_double(Dbee::Providers::ActiveRecordProvider::ExpressionBuilder).tap do |builder|
        expect(builder).to receive(:to_arel).with(query).and_return(
          Arel::Table.new(:users).project(Arel.sql('*'))
        )
      end
    end

    let(:derived_model) do
      Dbee::Model::Derived.new(
        name: 'derived_model',
        relationships: {
          other_model: { constraints: [{ name: 'other_model_id', parent: 'id' }] }
        },
        partitioners: [{ name: 'type', value: 'foo_type' }],
        query: {}
      )
    end

    let(:derived_model_builder) do
      Dbee::Providers::ActiveRecordProvider::DerivedModelBuilder.new(
        derived_model, expression_builder_double
      )
    end

    it "returns a subquery aliased to the subquery's name" do
      found_arel = described_class.new(derived_model_builder).to_arel

      expect(found_arel).to be_a Arel::Nodes::TableAlias
      expect(found_arel.name).to eq derived_model.name
      expect(found_arel.table_alias).to eq derived_model.name
    end

    it 'creates an alias based on the join path' do
      pending 'handle this as part of the effort to get table alias working with subqueries'
      # Note that the solution to this is probably to pass the alias into
      # DerivedModelBuilder#to_arel

      found_arel = described_class.new(derived_model_builder).to_arel(%w[level1 level2])

      expect(found_arel).to be_a Arel::Nodes::TableAlias
      expect(found_arel.name).to eq derived_model.name
      expect(found_arel.table_alias).to eq 'level1_level1'
    end
  end
end
