class RecipesController < ApplicationController
  def index
  end

  def match_ingredients
    ingredient_ids = params[:ingredient_ids]&.map(&:to_i) || []
    page = params[:page]&.to_i || 1

    result = RecipeSearchService.new(ingredient_ids, page).call

    respond_to do |format|
      format.json { render json: result }
      format.html { head :not_acceptable }
    end
  end
end
