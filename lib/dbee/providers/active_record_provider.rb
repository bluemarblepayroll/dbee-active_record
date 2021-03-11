# frozen_string_literal: true

#
# Copyright (c) 2019-present, Blue Marble Payroll, LLC
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

require 'dbee'
require 'active_record'

require_relative 'active_record_provider/derived_model_builder'
require_relative 'active_record_provider/derived_schema'
require_relative 'active_record_provider/expression_builder'
require_relative 'active_record_provider/joinable'
require_relative 'active_record_provider/obfuscated_alias_maker'
require_relative 'active_record_provider/safe_alias_maker'
require_relative 'active_record_provider/subquery_expression_builder'

module Dbee
  module Providers
    # Provider which leverages ActiveRecord and Arel for generating SQL.
    class ActiveRecordProvider
      DEFAULT_TABLE_PREFIX  = 't'
      DEFAULT_COLUMN_PREFIX = 'c'

      private_constant :DEFAULT_TABLE_PREFIX, :DEFAULT_COLUMN_PREFIX

      attr_reader :readable, :table_alias_maker, :column_alias_maker

      def initialize(
        readable: true,
        table_prefix: DEFAULT_TABLE_PREFIX,
        column_prefix: DEFAULT_COLUMN_PREFIX
      )
        @readable           = readable
        @table_alias_maker  = alias_maker(table_prefix)
        @column_alias_maker = alias_maker(column_prefix)
      end

      def sql(schema, query)
        ExpressionBuilder.new(
          schema,
          table_alias_maker,
          column_alias_maker
        ).to_sql(query)
      end

      private

      def alias_maker(prefix)
        readable ? SafeAliasMaker.new : ObfuscatedAliasMaker.new(prefix)
      end
    end
  end
end
