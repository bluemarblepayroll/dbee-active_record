# frozen_string_literal: true

#
# Copyright (c) 2019-present, Blue Marble Payroll, LLC
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

require_relative 'expression_builder/constraint'
require_relative 'expression_builder/order'
require_relative 'expression_builder/select'
require_relative 'expression_builder/where'

module Dbee
  module Providers
    class ActiveRecordProvider
      # This class can generate an Arel expression tree.
      class ExpressionBuilder
        class MissingConstraintError < StandardError; end

        def initialize(model, table_alias_maker, column_alias_maker)
          @model              = model
          @table_alias_maker  = table_alias_maker
          @column_alias_maker = column_alias_maker
          @requires_group_by  = false
          @group_by_columns   = []

          clear
        end

        def clear
          @base_table = make_table(model.table, model.name)

          build(base_table)

          add_partitioners(base_table, model.partitioners)
        end

        def add(query)
          query.fields.each   { |field| add_field(field) }
          query.sorters.each  { |sorter| add_sorter(sorter) }
          query.filters.each  { |filter| add_filter(filter) }

          add_limit(query.limit)

          self
        end

        def to_sql
          if requires_group_by
            @requires_group_by = false
            statement.group(group_by_columns) unless group_by_columns.empty?
            @group_by_columns = []
          end

          statement.to_sql
        end

        private

        attr_reader :base_table,
                    :statement,
                    :model,
                    :table_alias_maker,
                    :column_alias_maker,
                    :requires_group_by,
                    :group_by_columns

        def tables
          @tables ||= {}
        end

        def key_paths_to_arel_columns
          @key_paths_to_arel_columns ||= {}
        end

        def add_filter(filter)
          add_key_path(filter.key_path)

          key_path    = filter.key_path
          arel_column = key_paths_to_arel_columns[key_path]
          predicate   = Where.instance.make(filter, arel_column)

          build(statement.where(predicate))

          self
        end

        def add_sorter(sorter)
          add_key_path(sorter.key_path)

          key_path    = sorter.key_path
          arel_column = key_paths_to_arel_columns[key_path]
          predicate   = Order.instance.make(sorter, arel_column)

          build(statement.order(predicate))

          self
        end

        def add_filter_key_paths(filters)
          filters.each_with_object({}) do |filter, memo|
            arel_key_column = add_key_path(filter.key_path)

            memo[arel_key_column] = filter
          end
        end

        def add_field(field)
          arel_value_column           = add_key_path(field.key_path)
          arel_key_columns_to_filters = add_filter_key_paths(field.filters)

          predicate = Select.instance.make(
            field,
            arel_key_columns_to_filters,
            arel_value_column,
            column_alias_maker
          )

          build(statement.project(predicate))

          if field.aggregator?
            @requires_group_by = true
          else
            group_by_columns << arel_value_column
          end

          self
        end

        def add_limit(limit)
          limit = limit ? limit.to_i : nil

          build(statement.take(limit))

          self
        end

        def add_partitioners(table, partitioners)
          partitioners.each do |partitioner|
            arel_column = table[partitioner.name]
            predicate   = arel_column.eq(partitioner.value)

            build(statement.where(predicate))
          end

          self
        end

        def table(name, model, previous_table)
          table = make_table(model.table, name)

          on = Constraint.instance.make(model.constraints, table, previous_table)

          raise MissingConstraintError, "for: #{name}" unless on

          build(statement.join(table, ::Arel::Nodes::OuterJoin))
          build(statement.on(on))

          add_partitioners(table, model.partitioners)

          tables[name] = table
        end

        def traverse_ancestors(ancestors)
          ancestors.each_pair.inject(base_table) do |memo, (name, model)|
            tables.key?(name) ? tables[name] : table(name, model, memo)
          end
        end

        def add_key_path(key_path)
          return key_paths_to_arel_columns[key_path] if key_paths_to_arel_columns.key?(key_path)

          ancestors = model.ancestors!(key_path.ancestor_names)

          table = traverse_ancestors(ancestors)

          arel_column = table[key_path.column_name]

          # Note that this returns arel_column
          key_paths_to_arel_columns[key_path] = arel_column
        end

        def build(new_expression)
          @statement = new_expression
        end

        def make_table(table_name, alias_name)
          Arel::Table.new(table_name).tap do |table|
            table.table_alias = table_alias_maker.make(alias_name)
          end
        end
      end
    end
  end
end
