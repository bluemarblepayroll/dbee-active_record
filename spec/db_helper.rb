# frozen_string_literal: true

#
# Copyright (c) 2018-present, Blue Marble Payroll, LLC
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

# Enable logging using something like:
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
