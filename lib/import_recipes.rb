require "cgi"

class ImportRecipes
  def self.load_recipes(file_path = nil)
    file_path ||= Rails.root.join("db", "seed_data", "recipes-en.json")

    # Read English JSON array format
    recipes_data = JSON.parse(File.read(file_path))

    recipes_data.each do |recipe_data|
      process_recipe(recipe_data)
    end

    puts "Loaded #{Recipe.count} recipes with #{Ingredient.count} ingredients"
  end

  def self.process_recipe(recipe_data)
    # Extract and clean ingredients
    ingredients = extract_ingredients(recipe_data["ingredients"])

    # Create or find recipe
    recipe = Recipe.find_or_create_by!(name: recipe_data["title"])

    # Clear existing ingredients and add new ones
    recipe.ingredients.clear

    ingredients.each do |ingredient_name|
      ingredient = Ingredient.find_or_create_by!(name: ingredient_name)
      recipe.ingredients << ingredient unless recipe.ingredients.include?(ingredient)
    end

    # Update recipe with additional fields
    recipe.update!(
      ingredient_count: recipe.ingredients.count,
      cook_time: recipe_data["cook_time"],
      prep_time: recipe_data["prep_time"],
      rating: recipe_data["ratings"],
      category: recipe_data["category"],
      author: recipe_data["author"],
      image: normalize_image_url(recipe_data["image"]),
      ingredient_list: recipe_data["ingredients"]&.join(", ")
    )

    recipe
  end

  private

  def self.normalize_image_url(raw_url)
    return nil if raw_url.blank?

    # Handle proxied URLs like:
    # https://imagesvc.meredithcorp.io/v3/mm/image?url=https%3A%2F%2Fimages.media-allrecipes.com%2Fuserphotos%2F2298368.jpg
    if (m = raw_url.match(%r{\Ahttps?://imagesvc\.meredithcorp\.io/v3/mm/image\?url=(.+)\z}i))
      begin
        return CGI.unescape(m[1])
      rescue StandardError
        # Fall back to original on decode failure
        return raw_url
      end
    end

    raw_url
  end

  def self.extract_ingredients(ingredients_array)
    return [] unless ingredients_array.is_a?(Array)

    ingredients_array.map do |ingredient|
      # Clean ingredient name - remove quantities and measurements
      clean_ingredient_name(ingredient)
    end.compact.uniq
  end

  def self.clean_ingredient_name(ingredient_string)
    return nil if ingredient_string.blank?

    # Ensure proper encoding
    ingredient_string = ingredient_string.to_s.force_encoding("UTF-8")

    # Remove common quantity patterns including fractions
    cleaned = ingredient_string
      # Remove parentheses and their content (FIRST - to avoid comma splitting issues)
      .gsub(/\([^)]*\)/, "")
      # Remove everything after comma (preparation instructions, quantity notes, etc.)
      .gsub(/,.*$/, "")
      # Remove numbers with space and fractions with units (like "3 ½ teaspoons")
      .gsub(/\d+\s+[⅓⅔¼¾½⅛⅜⅝⅞]\s*(?:cup|cups|tablespoon|tablespoons|tsp|tbsp|teaspoon|teaspoons|pound|pounds|lb|lbs|ounce|ounces|oz|pint|pints|quart|quarts|gallon|gallons|gram|grams|g|kilogram|kilograms|kg|milliliter|milliliters|ml|liter|liters|l|can|cans|package|packages|bag|bags|bunch|bunches|head|heads|clove|cloves|slice|slices|piece|pieces|dash|pinch|handful|handfuls|cl)\s*/i, "")
      # Remove fractions with units (including Unicode fractions like ⅔)
      .gsub(/(?:[⅓⅔¼¾½⅛⅜⅝⅞]|\d+\/\d+)\s*(?:cup|cups|tablespoon|tablespoons|tsp|tbsp|teaspoon|teaspoons|pound|pounds|lb|lbs|ounce|ounces|oz|pint|pints|quart|quarts|gallon|gallons|gram|grams|g|kilogram|kilograms|kg|milliliter|milliliters|ml|liter|liters|l|can|cans|package|packages|bag|bags|bunch|bunches|head|heads|clove|cloves|slice|slices|piece|pieces|dash|pinch|handful|handfuls|cl)\s*/i, "")
      # Remove decimal numbers with English units (only when followed by actual units)
      .gsub(/\d+(?:\.\d+)?\s*(?:cup|cups|tablespoon|tablespoons|tsp|tbsp|teaspoon|teaspoons|pound|pounds|lb|lbs|ounce|ounces|oz|pint|pints|quart|quarts|gallon|gallons|gram|grams|g|kilogram|kilograms|kg|milliliter|milliliters|ml|liter|liters|l|can|cans|package|packages|bag|bags|bunch|bunches|head|heads|clove|cloves|slice|slices|piece|pieces|dash|pinch|handful|handfuls|cl)(?:\s|$)/i, "")
      # Remove any remaining numbers
      .gsub(/\d+(?:\.\d+)?\s*/i, "")
      # Remove Unicode fractions directly before ingredient names (without units)
      .gsub(/^[⅓⅔¼¾½⅛⅜⅝⅞]\s*/, "")
      # Remove leading English articles
      .gsub(/^\s*(?:a|an|the|some|any)\s+/i, "")
      # Remove any remaining slashes and clean up
      .gsub(/[\/\\]/, "")
      # Remove common descriptive words
      .gsub(/\s+(?:chopped|diced|sliced|minced|grated|shredded|crushed|beaten|drained|rinsed|peeled|seeded|cored|halved|quartered|cubed|julienned|finely|coarsely|fresh|dried|frozen|canned|cooked|raw|boneless|skinless|thinly|thickly|lightly|heavily|extra|optional|as needed|or to taste|to taste|refrigerated)\s*/i, "")
      # Remove descriptive words at the beginning
      .gsub(/^(?:chopped|diced|sliced|minced|grated|shredded|crushed|beaten|drained|rinsed|peeled|seeded|cored|halved|quartered|cubed|julienned|finely|coarsely|fresh|dried|frozen|canned|cooked|raw|boneless|skinless|thinly|thickly|lightly|heavily|extra|optional|as needed|or to taste|to taste|refrigerated)\s+/i, "")
      # Remove descriptive words that are attached to other words (like "choppedcilantro")
      .gsub(/([a-z])(?:chopped|diced|sliced|minced|grated|shredded|crushed|beaten|drained|rinsed|peeled|seeded|cored|halved|quartered|cubed|julienned|finely|coarsely|fresh|dried|frozen|canned|cooked|raw|boneless|skinless|thinly|thickly|lightly|heavily|extra|optional|as needed|or to taste|to taste|refrigerated)([a-z])/i, '\1\2')
      # Remove descriptive words at the very beginning when attached to other words
      .gsub(/^(?:chopped|diced|sliced|minced|grated|shredded|crushed|beaten|drained|rinsed|peeled|seeded|cored|halved|quartered|cubed|julienned|finely|coarsely|fresh|dried|frozen|canned|cooked|raw|boneless|skinless|thinly|thickly|lightly|heavily|extra|optional|as needed|or to taste|to taste|refrigerated)([a-z])/i, '\1')
      # Remove size descriptors (large, medium, small, etc.) but only when they're standalone
      .gsub(/\s+(?:large|medium|small|big|tiny|whole|half|quarter)\s+(?=\w)/i, " ")
      # Remove size descriptors at the beginning
      .gsub(/^(?:large|medium|small|big|tiny|whole|half|quarter)\s+/i, "")
      # Remove standalone "can" and "package" words
      .gsub(/\s+(?:can|package)\s+/i, " ")
      .gsub(/^(?:can|package)\s+/i, "")
      .gsub(/\s+(?:can|package)$/i, "")
      # Remove "can" and "package" when they're attached to other words
      .gsub(/([a-z])(?:can|package)([a-z])/i, '\1\2')
      .gsub(/^(?:can|package)([a-z])/i, '\1')
      .gsub(/([a-z])(?:can|package)$/i, '\1')
      # Remove "can" and "package" when they're followed by a word without space
      .gsub(/(?:can|package)([a-z])/i, '\1')
      # Remove leading commas and spaces (like ", chopped" -> "")
      .gsub(/^\s*,\s*/, "")
      # Clean up any leftover single letters (like 's' from 'teaspoons') but be more careful
      .gsub(/\s+[a-z]\s+/i, " ")
      .gsub(/^\s*[a-z]\s+/i, "")
      .gsub(/\s+[a-z]$/i, "")
      # Clean up double spaces
      .gsub(/\s+/, " ")
      .strip
      .downcase
      .singularize

    # Skip if empty or too short
    return nil if cleaned.blank? || cleaned.length < 2

    # Ignore common ingredients that everyone has
    return nil if cleaned == "water" || cleaned == "salt" || cleaned == "pepper"

    # Ignore ingredients containing "salt and" (salt and pepper, salt and herbs, etc.)
    return nil if cleaned.include?("salt and")

    cleaned
  end
end
