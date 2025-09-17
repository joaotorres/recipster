class AddIndexesForRecipeSearch < ActiveRecord::Migration[8.0]
  def change
    # Index for faster recipe lookups by ingredient
    add_index :ingredients_recipes, [ :ingredient_id, :recipe_id ], name: 'idx_ingredients_recipes_ingredient_recipe'

    # Index for faster ingredient lookups by recipe
    add_index :ingredients_recipes, [ :recipe_id, :ingredient_id ], name: 'idx_ingredients_recipes_recipe_ingredient'

    # Index for faster sorting by ingredient count
    add_index :recipes, :ingredient_count, name: 'idx_recipes_ingredient_count'

    # Index for ingredient name searches (autocomplete)
    add_index :ingredients, :name, name: 'idx_ingredients_name'
  end
end
