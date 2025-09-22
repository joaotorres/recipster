class IngredientsController < ApplicationController
  def search
    query = params[:q]&.downcase
    return render json: [] if query.blank?

    # First, get ingredients that start with the query (highest priority)
    # Order by name length ascending to show shorter, more specific names first
    starts_with_query = Ingredient.where("LOWER(name) LIKE ?", "#{query}%").order("LENGTH(name) ASC")

    # Then, get ingredients that contain the query but don't start with it
    contains_query = Ingredient.where("LOWER(name) LIKE ? AND LOWER(name) NOT LIKE ?", "%#{query}%", "#{query}%")

    # Combine and deduplicate, prioritizing starts_with results
    @ingredients = (starts_with_query.to_a + contains_query.to_a).uniq.first(30)

    respond_to do |format|
      format.json { render json: @ingredients }
    end
  end
end
