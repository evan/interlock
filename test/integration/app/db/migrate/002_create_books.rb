class CreateBooks < ActiveRecord::Migration
  def self.up
    create_table :books, :id => false do |t|
      t.string :name
      t.string :description
      t.timestamps
    end
  end

  def self.down
    drop_table :books
  end
end
