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
                     .group('recipes.id')
                     .having('COUNT(ingredients.id) = ?', ingredient_ids.length)
    
    respond_to do |format|
      format.json { render json: @recipes.map { |recipe| { name: recipe.name, ingredients: recipe.ingredients.pluck(:name) } } }
    end
  end
end
