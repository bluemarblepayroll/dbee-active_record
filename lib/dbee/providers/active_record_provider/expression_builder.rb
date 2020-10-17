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

        def initialize(model, table_alias_maker, column_alias_maker, unscoped_model: nil)
          super(column_alias_maker)

          @model             = model
          @unscoped_model    = unscoped_model || model
          @table_alias_maker = table_alias_maker
          # TODO: dependency inject this and remove table_alias_maker as a direct dependency:
          @joinable_builder  = Dbee::Providers::ActiveRecordProvider::JoinableBuilder.new(
            table_alias_maker
          )

          clear
        end

        def clear
          @requires_group_by  = false
          @group_by_columns   = []
          @base_table         = joinable_builder.for_model(model)
          @select_all         = true
          @derived_model      = Dbee::Providers::ActiveRecordProvider::DerivedModel.new(
            model, joinable_builder
          )

          build(base_table.arel([base_table.name]))

          add_partitioners(base_table.arel, model.partitioners)
        end

        # TODO: remove these after refactoring:
        # rubocop:disable Metrics/AbcSize
        def add(query)
          return self unless query

          SubqueryExpressionBuilder.new(self).build(query.given) if query.given.any?

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

          return statement.project(select_maker.star(base_table.arel)).to_sql if select_all

          statement.to_sql
        end

        # Returns a new instance which is scoped to the specified model path.
        # Used to construct sub queries.
        def new_scoped_to_model_path(model_path)
          self.class.new(
            unscoped_model.ancestors!(model_path)[model_path],
            table_alias_maker,
            column_alias_maker,
            unscoped_model: model
          )
        end

        def append_to_model(joinable)
          derived_model.append!(joinable)
        end

        def finalize(subquery)
          joinable = joinable_builder.for_derived_model(subquery, statement.as(subquery.name.to_s))

          # TODO: clean this up. This is needed so that the grouping can be
          # added to the Arel statement as a side effect of calling to_sql on
          # the Expression. The solution is most likely to add some sort of
          # finalization/apply grouping method to this class to decouple this
          # from the SQL generation and make things more explicit.
          to_sql

          joinable
        end

        private

        attr_reader :base_table,
                    :derived_model,
                    :joinable_builder,
                    :model,
                    :table_alias_maker,
                    :requires_group_by,
                    :group_by_columns,
                    :select_all,
                    :statement,
                    :unscoped_model

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
        def table(path, joinable, previous_joinable)
          on = constraint_maker.make(
            joinable.constraints, joinable.arel(path), previous_joinable.arel
          )

          raise MissingConstraintError, "for: #{joinable.name}" unless on

          build(statement.join(joinable.arel, ::Arel::Nodes::OuterJoin))
          build(statement.on(on))

          add_partitioners(joinable.arel, joinable.partitioners)

          tables[path] = joinable
        end
        # rubocop:enable Metrics/AbcSize

        # This returns a table which corresponds to the given ancestor path.
        # The argument is a ordered hash with keys being arrays of model name
        # paths and values being Dbee::Model's. This has a side effect of
        # creating Arel Tables for each model along that chain.
        def traverse_ancestors(ancestors)
          ancestors.each_pair.inject(base_table) do |memo, (path, joinable)|
            tables.key?(path) ? tables[path] : table(path, joinable, memo)
          end
        end

        def add_key_path(key_path)
          return key_paths_to_arel_columns[key_path] if key_paths_to_arel_columns.key?(key_path)

          ancestors = derived_model.ancestors!(key_path.ancestor_names)
          # puts "key_path: #{key_path}, ancestors: #{ancestors.keys.inspect}"

          joinable = traverse_ancestors(ancestors)
          arel_column = joinable.arel[key_path.column_name]

          # Note that this returns an arel_column.
          key_paths_to_arel_columns[key_path] = arel_column
        end

        def build(new_expression)
          @statement = new_expression
        end
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
