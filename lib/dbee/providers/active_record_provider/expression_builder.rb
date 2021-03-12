# frozen_string_literal: true

#
# Copyright (c) 2019-present, Blue Marble Payroll, LLC
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

require_relative 'maker'

module Dbee
  module Providers
    class ActiveRecordProvider
      # This class can generate an Arel expression tree given a Dbee::Schema
      # and Dbee::Query.
      class ExpressionBuilder < Maker # :nodoc: all
        class MissingConstraintError < StandardError; end

        attr_reader :column_alias_maker, :table_alias_maker, :schema

        def initialize(schema, table_alias_maker, column_alias_maker)
          super(column_alias_maker)

          @schema            = schema
          @table_alias_maker = table_alias_maker
        end

        def to_arel(query)
          reset_query_state
          build_query(query)

          return statement.project(select_maker.star(base_table)) if select_all

          statement
        end

        def to_sql(query)
          to_arel(query).to_sql
        end

        private

        attr_reader :base_table,
                    :key_paths_to_arel_columns,
                    :from_model, # TODO: rename to from_joinable
                    :statement,
                    :requires_group_by,
                    :group_by_columns,
                    :select_all,
                    :tables

        def reset_query_state
          @base_table = nil
          @key_paths_to_arel_columns = {}
          @from_model        = nil
          @group_by_columns  = []
          @requires_group_by = false
          @select_all        = true
          @tables            = {}
        end

        def build_query(query)
          establish_query_base(query)

          # SubqueryExpressionBuilder.new(self).build(query.given) if query.given.any?

          process_fields_sorters_and_filters(query)

          add_partitioners(base_table, from_model.partitioners)
          add_limit(query.limit)

          statement.group(group_by_columns) if requires_group_by && !group_by_columns.empty?
        end

        def establish_query_base(query)
          @from_model = schema.joinable_for_model_name!(query.from)
          @base_table = @from_model.to_arel(from_model.name)
          build(base_table)
        end

        def process_fields_sorters_and_filters(query)
          query.fields.each   { |field| add_field(field) }
          query.sorters.each  { |sorter| add_sorter(sorter) }
          query.filters.each  { |filter| add_filter(filter) }
        end

        def add_filter(filter)
          add_key_path(filter.key_path)

          key_path    = filter.key_path
          arel_column = key_paths_to_arel_columns[key_path]
          predicate   = where_maker.make(filter, arel_column)

          build(statement.where(predicate))

          self
        end

        def add_sorter(sorter)
          add_key_path(sorter.key_path)

          key_path    = sorter.key_path
          arel_column = key_paths_to_arel_columns[key_path]
          predicate   = order_maker.make(sorter, arel_column)

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
          @select_all                 = false
          arel_value_column           = add_key_path(field.key_path)
          arel_key_columns_to_filters = add_filter_key_paths(field.filters)

          predicate = select_maker.make(
            field,
            arel_key_columns_to_filters,
            arel_value_column
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

        def table(ancestor_names, relationship, model, previous_table)
          table = model.to_arel(ancestor_names)

          on = constraint_maker.make(relationship.constraints, table, previous_table)

          raise MissingConstraintError, "for: #{ancestor_names}" unless on

          build(statement.join(table, ::Arel::Nodes::OuterJoin))
          build(statement.on(on))

          add_partitioners(table, model.partitioners)

          tables[ancestor_names] = table
        end

        # Travel the query path returning the table at the end of the path.
        #
        # Side effect: intermediate tables are created along the way and are
        # added to the "tables" hash keyed by path.
        def traverse_query_path(expanded_query_path)
          visited_path = []

          expanded_query_path.inject(base_table) do |prev_model, (relationship, next_model)|
            visited_path += [relationship.name]
            if tables.key?(visited_path)
              tables[visited_path]
            else
              table(visited_path, relationship, next_model, prev_model)
            end
          end
        end

        def add_key_path(key_path)
          return key_paths_to_arel_columns[key_path] if key_paths_to_arel_columns.key?(key_path)

          expanded_query_path = schema.expand_query_path(from_model, key_path)
          table = traverse_query_path(expanded_query_path)

          arel_column = table[key_path.column_name]

          # Note that this returns arel_column
          key_paths_to_arel_columns[key_path] = arel_column
        end

        def build(new_expression)
          @statement = new_expression
        end
      end
    end
  end
end
