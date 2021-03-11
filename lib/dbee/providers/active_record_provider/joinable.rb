# frozen_string_literal: true

#
# Copyright (c) 2019-present, Blue Marble Payroll, LLC
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

require_relative 'makers/constraint'
require_relative 'makers/order'
require_relative 'makers/select'
require_relative 'makers/where'

module Dbee
  module Providers
    class ActiveRecordProvider
      # This encapsulates something that can be joined to in a SQL query. This
      # can either be a physical table OR a derived table generated from a
      # subquery.
      class Joinable # :nodoc: all
        extend Forwardable

        attr_reader :model, :table_alias_maker

        def_delegators :model, :name, :partitioners, :relationships

        def initialize(
          model,
          table_alias_maker: Dbee::Providers::ActiveRecordProvider::SafeAliasMaker.new
        )
          @model = model || raise(ArgumentError, 'model is required')
          @table_alias_maker = table_alias_maker
        end

        def to_arel(join_path = [])
          # Intentional disable to avoid having an memoized variable starting
          # with a verb.
          # rubocop:disable Naming/MemoizedInstanceVariableName
          @arel ||= model.respond_to?(:to_arel) ? model.to_arel : make_table(join_path)
          # rubocop:enable Naming/MemoizedInstanceVariableName
        end

        def ==(other)
          # TODO: add support for table_alias_maker
          other.instance_of?(self.class) && other.model == model
        end

        private

        def make_table(join_path)
          Arel::Table.new(model.table).tap do |arel_table|
            arel_table.table_alias = table_alias_maker.make(join_path)
          end
        end
      end
    end
  end
end
