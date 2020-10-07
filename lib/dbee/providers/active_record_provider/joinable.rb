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
        attr_reader :arel, :constraints, :name, :parent_model

        def initialize(arel:, constraints:, name:, parent_model:)
          @arel = arel
          @constraints = constraints
          @name = name
          @parent_model = parent_model

          freeze
        end
      end

      # Can create `Joinables` from `Dbee::Model`s or from derived models and
      # using table aliasing.
      class JoinableBuilder
        attr_reader :table_alias_maker

        def initialize(table_alias_maker)
          @table_alias_maker = table_alias_maker
          raise ArgumentError, 'a table alias maker is required' unless table_alias_maker

          freeze
        end

        def for_model(model)
          Joinable.new(
            arel: make_table(model.table, model.name),
            name: model.name,
            constraints: model.constraints,
            parent_model: nil # this could be determined if Dbee::Model was enhanced
          )
        end

        def for_derived_model(subquery, arel)
          Joinable.new(
            arel: arel,
            name: subquery.name,
            constraints: subquery.constraints,
            parent_model: subquery.parent
          )
        end

        private

        def make_table(table_name, alias_name)
          Arel::Table.new(table_name).tap do |table|
            table.table_alias = table_alias_maker.make(alias_name)
          end
        end
      end
    end
  end
end

# # Two level example:

# # Most inner query:
# derived_tree_path = []

# # Second level query:
# derived_tree_path = [['theater_ticket_pricing_effective_dates']]
# # derived_tree_path = [
# #   ["ticket_prices"],
# #   ["ticket_prices", 'theater_ticket_pricing_effective_dates']
# # ]

# Joinable(
#   arel: arel,
#   name: 'theater_ticket_pricing_effective_dates',
#   constraints: ...,
#   parent_model: 'ticket_prices',
# )

# # Top query:
# derived_tree_path = [["effective_ticket_prices"]]
# Joinable(
#   arel: arel,
#   name: 'effective_ticket_prices',
#   constraints: ...,
#   parent_model: 'theaters',
# )

# # One subquery example:

# # Subquery
# derived_tree_path = []

# # Outer query
# derived_tree_path = [
#   ["ticket_prices"],
#   ["ticket_prices", "effective_ticket_prices"]
# ]

# Joinable(
#   arel: arel,
#   name: 'effective_ticket_prices',
#   constraints: ...,
#   parent_model: 'ticket_prices'
# )
