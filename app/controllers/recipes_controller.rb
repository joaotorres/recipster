class RecipesController < ApplicationController
  def index
  end

  def match_ingredients
    ingredient_ids = params[:ingredient_ids] || []
    page = params[:page] || 1

    # First, find recipes that have at least one of the searched ingredients with match counts
    recipe_data = Recipe.joins(:ingredients)
                        .where(ingredients: { id: ingredient_ids })
                        .select("recipes.id, COUNT(DISTINCT ingredients.id) AS matched_ingredients_count")
                        .group("recipes.id")
                        .order(Arel.sql("(recipes.ingredient_count - COUNT(DISTINCT ingredients.id)) ASC, matched_ingredients_count DESC"))

    # Apply pagination to the recipe IDs
    paginated_recipe_data = Kaminari.paginate_array(recipe_data.to_a).page(page).per(20)

    # Extract the data we need and preserve order
    ordered_recipe_data = []
    matched_counts = {}

    paginated_recipe_data.each do |recipe|
      ordered_recipe_data << { id: recipe.id, matched_count: recipe.matched_ingredients_count }
      matched_counts[recipe.id] = recipe.matched_ingredients_count
    end

    # Now get all recipes with their complete ingredient lists, maintaining order
    recipes_by_id = Recipe.where(id: ordered_recipe_data.map { |r| r[:id] })
                          .includes(:ingredients)
                          .index_by(&:id)

    respond_to do |format|
      format.json { render json: {
          recipes: ordered_recipe_data.map { |recipe_data|
            recipe = recipes_by_id[recipe_data[:id]]
            matched_count = recipe_data[:matched_count]

            {
              name: recipe.name,
              ingredients: recipe.ingredients.map(&:name), # All ingredients, not just matched ones
              matched_ingredients_count: matched_count,
              total_ingredients_count: recipe.ingredient_count,
              missing_ingredients_count: recipe.ingredient_count - matched_count
            }
          },
          pagination: {
            current_page: paginated_recipe_data.current_page,
            total_pages: paginated_recipe_data.total_pages,
            total_count: paginated_recipe_data.total_count,
            per_page: paginated_recipe_data.limit_value,
            has_next_page: paginated_recipe_data.next_page.present?,
            has_prev_page: paginated_recipe_data.prev_page.present?
          }
        }
      }
    end
  end
end
