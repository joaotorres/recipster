class IngredientsController < ApplicationController
  def index
  end

  def search
    query = params[:q]&.downcase
    @ingredients = Ingredient.where("name LIKE ?", "%#{query}%").limit(10)

    respond_to do |format|
      format.json { render json: @ingredients }
    end
  end

  def match_ingredients
    ingredient_ids = params[:ingredient_ids] || []

    @recipes = Recipe.joins(:ingredients)
                      .where(ingredients: { id: ingredient_ids })
                      .select("recipes.*, COUNT(DISTINCT ingredients.id) AS matched_ingredients_count")
                      .group("recipes.id")
                      .order(Arel.sql("(ingredient_count - COUNT(DISTINCT ingredients.id)) ASC, matched_ingredients_count DESC"))

    respond_to do |format|
      format.json { render json: @recipes.map { |recipe|
          {
            name: recipe.name,
            ingredients: recipe.ingredients.pluck(:name),
            matched_ingredients_count: recipe.matched_ingredients_count,
            total_ingredients_count: recipe.ingredient_count,
            missing_ingredients_count: recipe.ingredient_count - recipe.matched_ingredients_count
          }
        }
      }
    end
  end
end
