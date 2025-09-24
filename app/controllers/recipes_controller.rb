class RecipesController < ApplicationController
  def index
  end

  def search
    filters = {
      name: params[:name],
      category: params[:category],
      min_rating: params[:min_rating]&.to_f,
      max_time: params[:max_time]&.to_i
    }.compact

    ingredient_ids = params[:ingredient_ids]&.map(&:to_i) || []
    page = params[:page]&.to_i || 1

    result = RecipeSearchService.new(ingredient_ids, filters, page).call

    respond_to do |format|
      format.json { render json: result }
      format.html { head :not_acceptable }
    end
  end
end
