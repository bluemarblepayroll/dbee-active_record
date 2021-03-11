# frozen_string_literal: true

#
# Copyright (c) 2019-present, Blue Marble Payroll, LLC
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

require 'spec_helper'
require 'db_helper'

describe Dbee::Providers::ActiveRecordProvider::ExpressionBuilder do
  let(:schema)      { Dbee::Schema.new(models['Patients']) }
  let(:alias_maker) { Dbee::Providers::ActiveRecordProvider::SafeAliasMaker.new }

  let(:empty_query) { Dbee::Query.make(from: :patients) }

  let(:id_and_average_query) do
    Dbee::Query.make(
      from: :patients,
      fields: [
        {
          key_path: :id,
          display: 'ID #'
        },
        {
          key_path: 'patient_payments.amount',
          display: 'Ave Payment',
          aggregator: :ave
        }
      ],
      sorters: [
        {
          key_path: :id
        }
      ],
      filters: [
        {
          key_path: :id,
          value: 123
        }
      ]
    )
  end

  let(:first_and_count_query) do
    Dbee::Query.make(
      from: :patients,
      fields: [
        {
          key_path: :first,
          display: 'First Name'
        },
        {
          key_path: 'patient_payments.amount',
          display: 'Number of Payments',
          aggregator: :count
        }
      ]
    )
  end

  subject { described_class.new(schema, alias_maker, alias_maker) }

  before(:all) do
    connect_to_db(:sqlite)
  end

  describe '#to_sql' do
    specify 'when called with no fields, then called with fields removes star select' do
      expect(subject.to_sql(empty_query)).to include('*')
      expect(subject.to_sql(id_and_average_query)).not_to include('*')
    end

    context 'with aggregation' do
      it 'generates the same sql when called multiple times' do
        first_sql  = subject.to_sql(id_and_average_query)
        second_sql = subject.to_sql(id_and_average_query)

        expect(first_sql).to eq(second_sql)

        third_sql  = subject.to_sql(first_and_count_query)
        fourth_sql = subject.to_sql(first_and_count_query)

        expect(third_sql).to eq(fourth_sql)
      end
    end
  end
end
