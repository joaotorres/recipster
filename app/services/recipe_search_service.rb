class RecipeSearchService
  PER_PAGE = 20

  def initialize(ingredient_ids = [], filters = {}, page = 1)
    @ingredient_ids = Array(ingredient_ids).compact
    @filters = filters || {}
    @page = page.to_i.positive? ? page.to_i : 1
  end

  def call
    # Check if we have any search criteria
    has_search_criteria = @ingredient_ids.any? || @filters.any?

    # Start with base query
    base_query = if @ingredient_ids.any?
      # Filter by ingredients first with proper matching logic
      find_matching_recipes_with_counts
    elsif has_search_criteria
      # No ingredients but other filters - get all recipes
      Recipe.all
    else
      # No search criteria - show top-rated recipes
      Recipe.all.order(rating: :desc)
    end

    # Apply additional filters
    filtered_query = apply_filters(base_query)

    # Handle pagination differently based on whether we have ingredient matching
    if @ingredient_ids.any?
      handle_ingredient_matching_pagination(filtered_query)
    else
      handle_regular_pagination(filtered_query)
    end
  end

  private

  def find_matching_recipes_with_counts
    Recipe.joins(:ingredients)
          .where(ingredients: { id: @ingredient_ids })
          .select("recipes.id, COUNT(DISTINCT ingredients.id) AS matched_ingredients_count, recipes.rating")
          .group("recipes.id, recipes.rating")
          .order(Arel.sql("(recipes.ingredient_count - COUNT(DISTINCT ingredients.id)) ASC, COUNT(DISTINCT ingredients.id) DESC, recipes.rating DESC"))
  end

  def apply_filters(query)
    # If we're dealing with ingredient matching results, we need to handle this differently
    if @ingredient_ids.any? && query.respond_to?(:select_values) && query.select_values.include?("recipes.id, COUNT(DISTINCT ingredients.id) AS matched_ingredients_count")
      # We have ingredient matching results, need to apply filters to the base Recipe model
      recipe_ids = query.pluck(:id)
      filtered_recipes = Recipe.where(id: recipe_ids)

      # Apply filters to the filtered recipes
      filtered_recipes = filtered_recipes.where("LOWER(recipes.name) LIKE ?", "%#{@filters[:name].downcase}%") if @filters[:name].present?
      filtered_recipes = filtered_recipes.where("LOWER(recipes.category) LIKE ?", "%#{@filters[:category].downcase}%") if @filters[:category].present?
      filtered_recipes = filtered_recipes.where("recipes.rating >= ?", @filters[:min_rating]) if @filters[:min_rating].present?
      filtered_recipes = filtered_recipes.where("(recipes.prep_time + recipes.cook_time) <= ?", @filters[:max_time]) if @filters[:max_time].present?

      # Return the original query filtered by the filtered recipe IDs
      query.where("recipes.id IN (?)", filtered_recipes.pluck(:id))
    else
      # Regular filtering for non-ingredient queries
      query = query.where("LOWER(recipes.name) LIKE ?", "%#{@filters[:name].downcase}%") if @filters[:name].present?
      query = query.where("LOWER(recipes.category) LIKE ?", "%#{@filters[:category].downcase}%") if @filters[:category].present?
      query = query.where("recipes.rating >= ?", @filters[:min_rating]) if @filters[:min_rating].present?
      query = query.where("(recipes.prep_time + recipes.cook_time) <= ?", @filters[:max_time]) if @filters[:max_time].present?
      query
    end
  end

  def handle_ingredient_matching_pagination(filtered_query)
    # Get the recipe data with match counts
    recipe_data = filtered_query.to_a

    # Apply pagination to the recipe IDs
    paginated_recipe_data = Kaminari.paginate_array(recipe_data).page(@page).per(PER_PAGE)

    # Extract the data we need and preserve order
    ordered_recipe_data = extract_ordered_data(paginated_recipe_data)

    # Now get all recipes with their complete ingredient lists, maintaining order
    recipes_by_id = fetch_complete_recipes(ordered_recipe_data)

    {
      recipes: build_recipe_results(ordered_recipe_data, recipes_by_id),
      pagination: build_pagination_data(paginated_recipe_data)
    }
  end

  def handle_regular_pagination(filtered_query)
    # Regular pagination for non-ingredient queries
    paginated_results = filtered_query.includes(:ingredients).page(@page).per(PER_PAGE)

    {
      recipes: build_regular_recipe_results(paginated_results),
      pagination: {
        current_page: paginated_results.current_page,
        total_pages: paginated_results.total_pages,
        total_count: paginated_results.total_count,
        per_page: paginated_results.limit_value,
        has_next_page: paginated_results.next_page.present?,
        has_prev_page: paginated_results.prev_page.present?
      }
    }
  end

  def extract_ordered_data(paginated_recipe_data)
    paginated_recipe_data.map do |recipe|
      {
        id: recipe.id,
        matched_count: recipe.matched_ingredients_count,
        rating: recipe.rating
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
        id: recipe.id,
        name: recipe.name,
        ingredients: recipe.ingredients.map(&:name),
        matched_ingredients_count: matched_count,
        total_ingredients_count: recipe.ingredient_count,
        missing_ingredients_count: recipe.ingredient_count - matched_count,
        image: recipe.image,
        prep_time: recipe.prep_time,
        cook_time: recipe.cook_time,
        rating: recipe_data[:rating], # Use the preserved rating from the ordered query
        category: recipe.category
      }
    end
  end

  def build_regular_recipe_results(paginated_results)
    paginated_results.map do |recipe|
      if @ingredient_ids.any?
        # When ingredients are selected, calculate matching counts
        matched_count = count_matched_ingredients(recipe)
        {
          id: recipe.id,
          name: recipe.name,
          ingredients: recipe.ingredients.map(&:name),
          matched_ingredients_count: matched_count,
          total_ingredients_count: recipe.ingredient_count,
          missing_ingredients_count: recipe.ingredient_count - matched_count,
          image: recipe.image,
          prep_time: recipe.prep_time,
          cook_time: recipe.cook_time,
          rating: recipe.rating,
          category: recipe.category
        }
      else
        # When no ingredients are selected, don't show matching information
        {
          id: recipe.id,
          name: recipe.name,
          ingredients: recipe.ingredients.map(&:name),
          matched_ingredients_count: nil,
          total_ingredients_count: recipe.ingredient_count,
          missing_ingredients_count: nil,
          image: recipe.image,
          prep_time: recipe.prep_time,
          cook_time: recipe.cook_time,
          rating: recipe.rating,
          category: recipe.category
        }
      end
    end
  end

  def count_matched_ingredients(recipe)
    recipe.ingredients.where(id: @ingredient_ids).count
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
