# frozen_string_literal: true

#
# Copyright (c) 2019-present, Blue Marble Payroll, LLC
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

require 'date'

module Models
  class Theaters < Dbee::Base
    table :theaters
    child :effective_ticket_prices
    child :ticket_prices
  end

  class TicketPrice < Dbee::Base
    table :ticket_prices
    parent :theaters
  end

  class EffectiveTicketPrice < Dbee::Base
    parent :theaters

    query({
            model: :'theaters.ticket_prices',
            filters: [
              {
                # Coearce the join to theater_ticket_pricing_effective_dates to an inner join:
                key_path: :'theater_ticket_pricing_effective_dates.theater_id',
                type: :not_equals,
                value: nil
              }
            ],
            given: [
              {
                name: :theater_ticket_pricing_effective_dates,
                model: :'theaters.ticket_prices',
                parent_model: :ticket_prices,
                constraints: [
                  { name: :theater_id, parent: :theater_id },
                  { name: :effective_date, parent: :effective_date }
                ],
                fields: [
                  { key_path: :theater_id },
                  { key_path: :effective_date, aggregator: :max }
                ],
                filters: [
                  { key_path: :effective_date, type: :less_than_or_equal_to, value: '2017-01-01' }
                ]
              }
            ]
          })
  end
end

module ReadmeDataModels
  class PhoneNumber < Dbee::Base
    table :phones
  end

  class Note < Dbee::Base; end

  class Patient < Dbee::Base
    child :notes

    child :work_phone_number, model: PhoneNumber, static: {
      name: :phone_number_type, value: 'work'
    }

    child :cell_phone_number, model: PhoneNumber, constraints: [
      { type: :static, name: :phone_number_type, value: 'cell' }
    ]

    child :fax_phone_number, model: PhoneNumber, constraints: [
      { type: :static, name: :phone_number_type, value: 'fax' }
    ]
  end

  class Practice < Dbee::Base
    association :patients, constraints: {
      type: :reference, name: :practice_id, parent: :id
    }
  end
end

module Cycles
  class BaseA < Dbee::Base
    association :b1, model: 'Cycles::B'
  end

  class A < BaseA
    table :as

    association :b2, model: 'Cycles::B'
  end

  class B < Dbee::Base
    association :c

    association :d
  end

  class C < Dbee::Base
    association :a
  end

  class D < Dbee::Base
    association :a
  end
end

# Examples of Rails Single Table Inheritance.
module PartitionerExamples
  class Owner < Dbee::Base
    child :dogs
  end

  class Animal < Dbee::Base; end

  class Dog < Animal
    partitioner :type, 'Dog'

    partitioner :deleted, false
  end
end
