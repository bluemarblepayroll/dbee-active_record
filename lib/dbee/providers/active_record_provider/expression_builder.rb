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
      # This class can generate an Arel expression tree.

      # TODO: break up this class
      # rubocop:disable Metrics/ClassLength
      class ExpressionBuilder < Maker # :nodoc: all
        class MissingConstraintError < StandardError; end

        def initialize(model, table_alias_maker, column_alias_maker)
          super(column_alias_maker)

          @model             = model
          @table_alias_maker = table_alias_maker

          clear
        end

        def clear
          @requires_group_by  = false
          @group_by_columns   = []
          @base_table         = make_table(model.table, model.name)
          @select_all         = true

          build(base_table)

          add_partitioners(base_table, model.partitioners)
        end

        # TODO: remove these after refactoring:
        # rubocop:disable Metrics/AbcSize
        def add(query)
          return self unless query

          query.given.each do |subquery|
            model_path = [subquery.model.to_s]
            subquery_expression = ExpressionBuilder.new(
              # TODO: this should probably pass in a proper key path to support
              # a subquery on a model beyond the first level of the model tree.
              # ALSO, it should find the result which matches the key path
              # instead of by model name.
              model.ancestors!(model_path)[model_path],
              table_alias_maker,
              column_alias_maker
            ).add(subquery)

            # This returns an Arel::Nodes::TableAlias
            derived_tables[subquery.name.to_s] = subquery_expression.send(:statement)
                                                                    .as(subquery.name.to_s)

            # Then that new "table" name needs to be appended to the model data
            # structure.
            # TODO: clean this up and handle more than one level of subquery
            # and respect encapsulation of Dbee::Model:
            model.send(:models_by_name)[subquery.model.to_s].append(
              Dbee::Model.new(
                name: subquery.name,
                constraints: subquery.constraints,
                table: subquery.name
              )
            )

            # TODO: clean this up. This is needed so that the grouping can be
            # added to the Arel statement as a side effect of calling to_sql on
            # the Expression. The solution is most likely to add some sort of
            # finalization/apply grouping method to this class to decouple this
            # from the SQL generation and make things more explicit.
            subquery_expression.to_sql
          end

          # TODO: this has a side effect of materializing the subqueries in
          # such a way that is helpful.
          # if subqueries.any?
          #   subqueries.map(&:to_sql)
          # end

          query.fields.each   { |field| add_field(field) }
          query.sorters.each  { |sorter| add_sorter(sorter) }
          query.filters.each  { |filter| add_filter(filter) }

          add_limit(query.limit)

          self
        end
        # rubocop:enable Metrics/AbcSize

        def to_sql
          if requires_group_by
            @requires_group_by = false
            statement.group(group_by_columns) unless group_by_columns.empty?
            @group_by_columns = []
          end

          return statement.project(select_maker.star(base_table)).to_sql if select_all

          statement.to_sql
        end

        private

        attr_reader :base_table,
                    :model,
                    :table_alias_maker,
                    :requires_group_by,
                    :group_by_columns,
                    :select_all,
                    :statement

        def tables
          @tables ||= {}
        end

        def derived_tables
          @derived_tables ||= {}
        end

        def key_paths_to_arel_columns
          @key_paths_to_arel_columns ||= {}
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

        # TODO: split up this method:
        # rubocop:disable Metrics/AbcSize
        def table(name, model, previous_table)
          table = derived_tables[model.table] || make_table(model.table, name)

          on = constraint_maker.make(model.constraints, table, previous_table)

          raise MissingConstraintError, "for: #{name}" unless on

          build(statement.join(table, ::Arel::Nodes::OuterJoin))
          build(statement.on(on))

          add_partitioners(table, model.partitioners)

          tables[name] = table
        end
        # rubocop:enable Metrics/AbcSize

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
    # rubocop:enable Metrics/ClassLength
  end
end
