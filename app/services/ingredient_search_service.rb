class IngredientSearchService
  MAX_RESULTS = 30

  def initialize(query)
    @query = query&.strip&.gsub(/\s+/, " ")&.downcase
  end

  def call
    return [] if @query.blank?

    prioritize_search_results
  end

  private

  def prioritize_search_results
    # First, get ingredients that start with the query (highest priority)
    # Order by name length ascending to show shorter, more specific names first
    starts_with_query = find_ingredients_starting_with_query

    # Then, get ingredients that contain the query but don't start with it
    contains_query = find_ingredients_containing_query

    # Combine and deduplicate, prioritizing starts_with results
    (starts_with_query.to_a + contains_query.to_a).uniq.first(MAX_RESULTS)
  end

  def find_ingredients_starting_with_query
    Ingredient.where("LOWER(name) LIKE ?", "#{@query}%")
              .order("LENGTH(name) ASC")
  end

  def find_ingredients_containing_query
    Ingredient.where("LOWER(name) LIKE ? AND LOWER(name) NOT LIKE ?",
                     "%#{@query}%", "#{@query}%")
  end
end
