class CreateReports < ActiveRecord::Migration[7.0]
  def change
    create_table :reports do |t|
      t.text :template
      t.string :generate_mode
      t.string :location
      t.datetime :delivery_date

      t.timestamps
    end
  end
end
