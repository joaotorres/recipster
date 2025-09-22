class RecipeSearchService
  PER_PAGE = 20

  def initialize(ingredient_ids, page = 1)
    @ingredient_ids = Array(ingredient_ids).compact
    @page = page.to_i.positive? ? page.to_i : 1
  end

  def call
    return empty_result if @ingredient_ids.empty?

    # First, find recipes that have at least one of the searched ingredients with match counts
    recipe_data = find_matching_recipes_with_counts

    # Apply pagination to the recipe IDs
    paginated_recipe_data = Kaminari.paginate_array(recipe_data.to_a).page(@page).per(PER_PAGE)

    # Extract the data we need and preserve order
    ordered_recipe_data = extract_ordered_data(paginated_recipe_data)

    # Now get all recipes with their complete ingredient lists, maintaining order
    recipes_by_id = fetch_complete_recipes(ordered_recipe_data)

    {
      recipes: build_recipe_results(ordered_recipe_data, recipes_by_id),
      pagination: build_pagination_data(paginated_recipe_data)
    }
  end

  private

  def empty_result
    {
      recipes: [],
      pagination: {
        current_page: 1,
        total_pages: 0,
        total_count: 0,
        per_page: PER_PAGE,
        has_next_page: false,
        has_prev_page: false
      }
    }
  end

  def find_matching_recipes_with_counts
    Recipe.joins(:ingredients)
          .where(ingredients: { id: @ingredient_ids })
          .select("recipes.id, COUNT(DISTINCT ingredients.id) AS matched_ingredients_count")
          .group("recipes.id")
          .order(Arel.sql("(recipes.ingredient_count - COUNT(DISTINCT ingredients.id)) ASC, matched_ingredients_count DESC"))
  end

  def extract_ordered_data(paginated_recipe_data)
    paginated_recipe_data.map do |recipe|
      {
        id: recipe.id,
        matched_count: recipe.matched_ingredients_count
      }
    end
  end

  def fetch_complete_recipes(ordered_recipe_data)
    Recipe.where(id: ordered_recipe_data.map { |r| r[:id] })
          .includes(:ingredients)
          .index_by(&:id)
  end

  def build_recipe_results(ordered_recipe_data, recipes_by_id)
    ordered_recipe_data.map do |recipe_data|
      recipe = recipes_by_id[recipe_data[:id]]
      matched_count = recipe_data[:matched_count]

      {
        name: recipe.name,
        ingredients: recipe.ingredients.map(&:name),
        matched_ingredients_count: matched_count,
        total_ingredients_count: recipe.ingredient_count,
        missing_ingredients_count: recipe.ingredient_count - matched_count,
        image: recipe.image,
        prep_time: recipe.prep_time,
        cook_time: recipe.cook_time,
        rating: recipe.rating
      }
    end
  end

  def build_pagination_data(paginated_recipe_data)
    {
      current_page: paginated_recipe_data.current_page,
      total_pages: paginated_recipe_data.total_pages,
      total_count: paginated_recipe_data.total_count,
      per_page: paginated_recipe_data.limit_value,
      has_next_page: paginated_recipe_data.next_page.present?,
      has_prev_page: paginated_recipe_data.prev_page.present?
    }
  end
end
