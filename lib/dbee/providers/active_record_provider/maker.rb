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
      # This class composes all the maker instances into one for use together.
      class Maker # :nodoc: all
        def initialize(column_alias_maker)
          @column_alias_maker = column_alias_maker
          @constraint_maker   = Makers::Constraint.instance
          @order_maker        = Makers::Order.instance
          @select_maker       = Makers::Select.new(column_alias_maker)
          @where_maker        = Makers::Where.instance
        end

        private

        attr_reader :column_alias_maker,
                    :constraint_maker,
                    :order_maker,
                    :select_maker,
                    :where_maker
      end
    end
  end
end
