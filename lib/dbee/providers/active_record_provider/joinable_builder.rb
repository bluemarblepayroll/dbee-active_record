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
      # Creates `Joinables` using table aliasing from `Dbee::Model`s or from
      # derived models.
      class JoinableBuilder # :nodoc:
        attr_reader :table_alias_maker

        def initialize(table_alias_maker)
          @table_alias_maker = table_alias_maker
          raise ArgumentError, 'a table alias maker is required' unless table_alias_maker

          freeze
        end

        def for_model(model)
          Joinable.new(
            name: model.name,
            constraints: model.constraints,
            parent_model: nil, # this could be determined if Dbee::Model was enhanced
            partitioners: model.partitioners,
            table: model.table,
            table_alias_maker: table_alias_maker
          )
        end

        def for_derived_model(subquery, arel)
          Joinable.new(
            arel: arel,
            name: subquery.name,
            constraints: subquery.constraints,
            parent_model: subquery.parent_model
          )
        end
      end
    end
  end
end
