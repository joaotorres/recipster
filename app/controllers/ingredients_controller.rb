class IngredientsController < ApplicationController
  def search
    ingredients = IngredientSearchService.new(params[:q]).call

    respond_to do |format|
      format.json { render json: ingredients }
      format.html { head :not_acceptable }
    end
  end
end
