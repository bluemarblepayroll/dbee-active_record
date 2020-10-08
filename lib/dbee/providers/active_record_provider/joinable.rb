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
        attr_reader :constraints, :name, :parent_model, :partitioners, :table, :table_alias_maker

        # TODO: refactor as suggested by Rubocop
        # rubocop:disable Metrics/ParameterLists
        def initialize(
          constraints:, name:, parent_model:, arel: nil,
          partitioners: [],
          table: nil,
          table_alias_maker: Dbee::Providers::ActiveRecordProvider::SafeAliasMaker.new
        )
          @arel = arel
          @constraints = constraints
          @name = name
          @parent_model = parent_model
          @partitioners = partitioners
          @table = table
          @table_alias_maker = table_alias_maker
        end
        # rubocop:enable Metrics/ParameterLists

        # TODO: move this idea to Dbee:
        def parent_model_path
          parent_model.split('.')
        end

        # TODO: CLEAN THIS UP! Adding the join path like this is a complete hack.
        def arel(join_path = [])
          @arel ||= make_table(join_path)
        end

        private

        def make_table(join_path)
          Arel::Table.new(table).tap do |arel_table|
            arel_table.table_alias = table_alias_maker.make(join_path)
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
