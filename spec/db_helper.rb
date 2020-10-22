# frozen_string_literal: true

#
# Copyright (c) 2018-present, Blue Marble Payroll, LLC
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

require_relative 'spec_helper'
require_relative 'fixtures/models'

# Enable SQL logging using:
# ActiveRecord::Base.logger = Logger.new(STDERR)

class Field < ActiveRecord::Base
  has_many :patient_field_values
end

class Patient < ActiveRecord::Base
  has_many :patient_field_values
  has_many :patient_payments

  accepts_nested_attributes_for :patient_field_values
  accepts_nested_attributes_for :patient_payments
end

class PatientFieldValue < ActiveRecord::Base
  belongs_to :patient
  belongs_to :field
end

class PatientPayment < ActiveRecord::Base
  belongs_to :patient
end

class Theater < ActiveRecord::Base
  has_many :ticket_prices

  accepts_nested_attributes_for :ticket_prices
end

class TicketPrice < ActiveRecord::Base
  belongs_to :theater
end

def connect_to_db(name)
  config = yaml_file_read('spec', 'config', 'database.yaml')[name.to_s]
  ActiveRecord::Base.establish_connection(config)
end

def load_schema
  ActiveRecord::Schema.define do
    # Movie Theater Schema
    create_table :theaters do |t|
      t.column :name,      :string
      t.column :partition, :string
      t.column :active,    :boolean
      t.column :inspected, :boolean
      t.timestamps
    end

    # Intentionally oversimplified. An actual movie theater price model would
    # have special matinee, child, senior, and many other types of tickets.
    create_table :ticket_prices do |t|
      t.column :theater_id,     :integer
      t.column :price_usd,      :decimal
      t.column :effective_date, :date
      t.timestamps
    end

    # Only one price an be in effect per theater on a given day.
    add_index :ticket_prices, %i[theater_id effective_date], unique: true

    create_table :members do |t|
      t.column :tid,            :integer
      t.column :account_number, :string
      t.column :partition,      :string
      t.timestamps
    end

    create_table :demographics do |t|
      t.column :member_id, :integer
      t.column :name,      :string
      t.timestamps
    end

    create_table :phone_numbers do |t|
      t.column :demographic_id, :integer
      t.column :phone_type,     :string
      t.column :phone_number,   :string
      t.timestamps
    end

    create_table :movies do |t|
      t.column :member_id, :integer
      t.column :name,      :string
      t.column :genre,     :string
      t.column :favorite,  :boolean, default: false, null: false
      t.timestamps
    end

    create_table :owners do |t|
      t.column :name, :string
      t.timestamps
    end

    create_table :animals do |t|
      t.column :owner_id, :integer
      t.column :toy_id,   :integer
      t.column :type,     :string
      t.column :name,     :string
      t.column :deleted,  :boolean
      t.timestamps
    end

    create_table :dog_toys do |t|
      t.column :squishy, :boolean
      t.timestamps
    end

    create_table :cat_toys do |t|
      t.column :laser, :boolean
      t.timestamps
    end

    # Patient Schema
    create_table :fields do |t|
      t.column :section, :string
      t.column :key,     :string
      t.timestamps
    end

    add_index :fields, %i[section key], unique: true

    create_table :patients do |t|
      t.column :first,  :string
      t.column :middle, :string
      t.column :last,   :string
      t.timestamps
    end

    create_table :patient_field_values do |t|
      t.column :patient_id, :integer, foreign_key: true
      t.column :field_id,   :integer, foreign_key: true
      t.column :value,      :string
      t.timestamps
    end

    add_index :patient_field_values, %i[patient_id field_id], unique: true

    create_table :patient_payments do |t|
      t.column :patient_id, :integer, foreign_key: true
      t.column :amount,     :decimal
      t.timestamps
    end
  end
end

def load_data
  load_patient_data
  load_movie_data
end

def load_patient_data
  demo_dob_field              = Field.create!(section: 'demographics', key: 'dob')
  demo_drivers_license_field  = Field.create!(section: 'demographics', key: 'drivers_license')
  demo_notes_field            = Field.create!(section: 'demographics', key: 'notes')

  contact_phone_number_field  = Field.create!(section: 'contact', key: 'phone_number')
  contact_notes_field         = Field.create!(section: 'contact', key: 'notes')

  Patient.create!(
    first: 'Bozo',
    middle: 'The',
    last: 'Clown',
    patient_field_values_attributes: [
      {
        field: demo_dob_field,
        value: '1904-04-04'
      },
      {
        field: demo_notes_field,
        value: 'The patient is funny!'
      },
      {
        field: demo_drivers_license_field,
        value: '82-54-hut-hut-hike!'
      },
      {
        field: contact_phone_number_field,
        value: '555-555-5555'
      },
      {
        field: contact_notes_field,
        value: 'Do not call this patient at night!'
      }
    ],
    patient_payments_attributes: [
      { amount: 5 },
      { amount: 10 },
      { amount: 15 }
    ]
  )

  Patient.create!(
    first: 'Frank',
    last: 'Rizzo',
    patient_payments_attributes: [
      { amount: 50 },
      { amount: 150 }
    ]
  )

  Patient.create!(
    first: 'Bugs',
    middle: 'The',
    last: 'Bunny',
    patient_field_values_attributes: [
      {
        field: demo_dob_field,
        value: '2040-01-01'
      },
      {
        field: contact_notes_field,
        value: 'Call anytime!!'
      }
    ]
  )
end

def load_movie_data
  Theater.create!(
    name: 'Small Town Movies',
    active: true,
    inspected: true,
    ticket_prices_attributes: [
      { price_usd: 5, effective_date: '2018-01-01' },
      { price_usd: 6, effective_date: '2019-01-01' },
      { price_usd: 7, effective_date: '2020-01-01' },
      { price_usd: 5, effective_date: '2020-04-01' },
      { price_usd: 7, effective_date: '2021-04-01' }
    ]
  )

  Theater.create!(
    name: 'Big City Megaplex',
    active: true,
    inspected: true,
    ticket_prices_attributes: [
      { price_usd: 10, effective_date: '2018-01-01' },
      { price_usd: 12, effective_date: '2019-01-31' },
      { price_usd: 14, effective_date: '2020-02-01' }
    ]
  )

  Theater.create!(
    name: 'Out of Business Theater',
    active: false,
    inspected: true,
    ticket_prices_attributes: [
      { price_usd: 10, effective_date: '2015-01-01' },
      { price_usd: 12, effective_date: '2016-01-01' },
      { price_usd: 14, effective_date: '2017-02-01' }
    ]
  )

  Theater.create!(
    name: 'Suburban Cinema',
    active: true,
    inspected: false,
    ticket_prices_attributes: [
      { price_usd: 9,  effective_date: '2018-01-01' },
      { price_usd: 10, effective_date: '2019-01-01' },
      { price_usd: 11, effective_date: '2020-02-01' }
    ]
  )
end
