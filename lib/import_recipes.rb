class ImportRecipes
  def self.load_recipes(file_path = nil)
    file_path ||= Rails.root.join("db", "seed_data", "recipes.json")

    # Read JSONL format (one JSON object per line)
    recipes_data = File.readlines(file_path).map { |line| JSON.parse(line.strip) }

    recipes_data.each do |recipe_data|
      # Extract and clean ingredients
      ingredients = extract_ingredients(recipe_data["ingredients"])

      # Create or find recipe
      recipe = Recipe.find_or_create_by!(name: recipe_data["name"])

      # Clear existing ingredients and add new ones
      recipe.ingredients.clear

      ingredients.each do |ingredient_name|
        ingredient = Ingredient.find_or_create_by!(name: ingredient_name)
        recipe.ingredients << ingredient unless recipe.ingredients.include?(ingredient)
      end

      # Update ingredient count
      recipe.update!(ingredient_count: recipe.ingredients.count)
    end

    puts "Loaded #{Recipe.count} recipes with #{Ingredient.count} ingredients"
  end

  private

  def self.extract_ingredients(ingredients_array)
    return [] unless ingredients_array.is_a?(Array)

    ingredients_array.map do |ingredient|
      # Clean ingredient name - remove quantities and measurements
      clean_ingredient_name(ingredient)
    end.compact.uniq
  end

  def self.clean_ingredient_name(ingredient_string)
    return nil if ingredient_string.blank?

    # Remove common quantity patterns including fractions
    cleaned = ingredient_string
      # Remove fractions like 1/2, 1/4, 3/4, etc.
      .gsub(/\d+\/\d+\s*/i, "")
      # Remove decimal numbers with units (including cuillère with à soupe/café)
      .gsub(/\d+(?:\.\d+)?\s*(?:kg|g|cl|ml|l|dl|cuillère(?:s)?\s*(?:à\s*(?:soupe|café))?|tasse|tasses|poignée|poignées|pincée|pincées|filet|branche|branches|botte|bouquet|gousse|gousses|morceau|morceaux|tranche|tranches|dose|doses|verre|verres|bâton|bâtons|grain|grains|clou|clous|tablette|tablettes|cube|cubes|bâtonnet|bâtonnets|sachet|sachets|paquet|paquets|boîte|boîtes|pot|pots|bouteille|bouteilles|canette|canettes|brique|briques|tube|tubes|flacon|flacons)\s*/i, "")
      # Remove any remaining cuillère patterns (without numbers)
      .gsub(/cuillère(?:s)?\s*/i, "")
      # Remove standalone "à soupe" and "à café" measurements (with or without numbers)
      .gsub(/(?:\d+(?:\.\d+)?\s*)?(?:s\s+)?à\s+(?:soupe|café)\s*/i, "")
      # Remove numbers with French articles
      .gsub(/\d+(?:\.\d+)?\s*(?:de|d'|du|des|la|le|les|l'|un|une|des|du|de la|de l'|de le|de les|de un|de une|de des|de du|de de la|de de l'|de de le|de de les|de de un|de de une|de de des|de de du|de de de la|de de de l'|de de de le|de de de les|de de de un|de de de une|de de de des|de de de du)\s*/i, "")
      # Remove any remaining numbers
      .gsub(/\d+(?:\.\d+)?\s*/i, "")
      # Remove leading French articles
      .gsub(/^\s*(?:de|d'|du|des|la|le|les|l'|un|une|des|du|de la|de l'|de le|de les|de un|de une|de des|de du|de de la|de de l'|de de le|de de les|de de un|de de une|de de des|de de du|de de de la|de de de l'|de de de le|de de de les|de de de un|de de de une|de de de des|de de de du)\s*/i, "")
      # Remove any remaining slashes and clean up
      .gsub(/[\/\\]/, "")
      # Remove parentheses and their content as final step
      .gsub(/\([^)]*\)/, "")
      .strip
      .downcase
      .singularize(:fr)

    # Skip if empty or too short
    return nil if cleaned.blank? || cleaned.length < 2

    cleaned
  end
end
