class AddFieldsToRecipes < ActiveRecord::Migration[8.0]
  def change
    add_column :recipes, :cook_time, :integer
    add_column :recipes, :prep_time, :integer
    add_column :recipes, :rating, :decimal
    add_column :recipes, :category, :string
    add_column :recipes, :author, :string
    add_column :recipes, :image, :string
    add_column :recipes, :ingredient_list, :text
  end
end
