# frozen_string_literal: true

#
# Copyright (c) 2019-present, Blue Marble Payroll, LLC
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

require 'spec_helper'
require 'db_helper'

describe Dbee::Providers::ActiveRecordProvider::Makers::Where do
  before(:all) { connect_to_db(:sqlite) }

  let(:subject) { described_class.instance }
  let(:column) { Arel::Table.new(:test)[:foo] }

  describe 'equals' do
    specify 'string value' do
      filter = Dbee::Query::Filters::Equals.new(key_path: :foo, value: 'bar')
      expect(subject.make(filter, column).to_sql).to eq %q("test"."foo" = 'bar')
    end

    specify 'null value' do
      filter = Dbee::Query::Filters::Equals.new(key_path: :foo, value: nil)
      expect(subject.make(filter, column).to_sql).to eq '"test"."foo" IS NULL'
    end
  end
end
