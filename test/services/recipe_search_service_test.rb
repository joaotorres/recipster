require "test_helper"

class RecipeSearchServiceTest < ActiveSupport::TestCase
  def setup
    # Clear existing data to avoid fixture interference
    Recipe.destroy_all
    Ingredient.destroy_all

    # Create test ingredients
    @flour = Ingredient.create!(name: "all-purpose flour")
    @egg = Ingredient.create!(name: "egg")
    @sugar = Ingredient.create!(name: "sugar")
    @butter = Ingredient.create!(name: "butter")

    # Create test recipes
    @recipe1 = Recipe.create!(
      name: "Chocolate Cake",
      category: "dessert",
      rating: 4.5,
      prep_time: 15,
      cook_time: 30,
      ingredient_count: 4,
      image: "cake.jpg"
    )
    @recipe1.ingredients = [ @flour, @egg, @sugar, @butter ]

    @recipe2 = Recipe.create!(
      name: "Pasta Carbonara",
      category: "main-course",
      rating: 4.2,
      prep_time: 10,
      cook_time: 20,
      ingredient_count: 3,
      image: "pasta.jpg"
    )
    @recipe2.ingredients = [ @flour, @egg, @butter ]

    @recipe3 = Recipe.create!(
      name: "Simple Pasta",
      category: "main-course",
      rating: 3.8,
      prep_time: 5,
      cook_time: 15,
      ingredient_count: 2,
      image: "simple-pasta.jpg"
    )
    @recipe3.ingredients = [ @flour, @egg ]
  end

  test "should return all recipes when no ingredient_ids provided" do
    service = RecipeSearchService.new([], {}, 1)
    result = service.call

    assert_equal 3, result[:recipes].length
    assert_equal 3, result[:pagination][:total_count]
  end

  test "should find recipes with ingredient matching" do
    service = RecipeSearchService.new([ @flour.id, @egg.id ], {}, 1)
    result = service.call

    assert_equal 3, result[:recipes].length
    assert_equal 3, result[:pagination][:total_count]

    # Should return all recipes since they all have both ingredients
    recipe_names = result[:recipes].map { |r| r[:name] }
    assert_includes recipe_names, "Chocolate Cake"
    assert_includes recipe_names, "Pasta Carbonara"
    assert_includes recipe_names, "Simple Pasta"
  end

  test "should apply name filter" do
    service = RecipeSearchService.new([ @flour.id, @egg.id ], { name: "pasta" }, 1)
    result = service.call

    assert_equal 2, result[:recipes].length
    recipe_names = result[:recipes].map { |r| r[:name] }
    assert_includes recipe_names, "Pasta Carbonara"
    assert_includes recipe_names, "Simple Pasta"
  end

  test "should apply rating filter" do
    service = RecipeSearchService.new([ @flour.id, @egg.id ], { min_rating: 4.0 }, 1)
    result = service.call

    assert_equal 2, result[:recipes].length
    recipe_names = result[:recipes].map { |r| r[:name] }
    assert_includes recipe_names, "Chocolate Cake"
    assert_includes recipe_names, "Pasta Carbonara"
  end

  test "should apply time filter" do
    service = RecipeSearchService.new([ @flour.id, @egg.id ], { max_time: 25 }, 1)
    result = service.call

    assert_equal 1, result[:recipes].length
    assert_equal "Simple Pasta", result[:recipes].first[:name]
  end

  test "should apply category filter" do
    service = RecipeSearchService.new([ @flour.id, @egg.id ], { category: "dessert" }, 1)
    result = service.call

    assert_equal 1, result[:recipes].length
    assert_equal "Chocolate Cake", result[:recipes].first[:name]
  end

  test "should apply multiple filters" do
    service = RecipeSearchService.new(
      [ @flour.id, @egg.id ],
      {
        name: "pasta",
        min_rating: 4.0,
        max_time: 30,
        category: "main-course"
      },
      1
    )
    result = service.call

    assert_equal 1, result[:recipes].length
    assert_equal "Pasta Carbonara", result[:recipes].first[:name]
  end

  test "should return recipes without ingredient matching when no ingredient_ids" do
    service = RecipeSearchService.new([], { name: "pasta" }, 1)
    result = service.call

    assert_equal 2, result[:recipes].length
    recipe_names = result[:recipes].map { |r| r[:name] }
    assert_includes recipe_names, "Pasta Carbonara"
    assert_includes recipe_names, "Simple Pasta"
  end

  test "should handle pagination" do
    service = RecipeSearchService.new([ @flour.id, @egg.id ], {}, 1)
    result = service.call

    assert_equal 1, result[:pagination][:current_page]
    assert_equal 1, result[:pagination][:total_pages]
    assert_equal 3, result[:pagination][:total_count]
    assert_equal 20, result[:pagination][:per_page]
  end

  test "should return complete recipe data with ingredients" do
    service = RecipeSearchService.new([ @flour.id, @egg.id ], {}, 1)
    result = service.call

    recipe = result[:recipes].first
    assert_includes recipe.keys, :name
    assert_includes recipe.keys, :ingredients
    assert_includes recipe.keys, :matched_ingredients_count
    assert_includes recipe.keys, :total_ingredients_count
    assert_includes recipe.keys, :missing_ingredients_count
    assert_includes recipe.keys, :image
    assert_includes recipe.keys, :prep_time
    assert_includes recipe.keys, :cook_time
    assert_includes recipe.keys, :rating
    assert_includes recipe.keys, :category

    # All recipes should have 2 matched ingredients (flour and egg)
    assert_equal 2, recipe[:matched_ingredients_count]

    # Check that the recipe has the expected structure
    assert recipe[:total_ingredients_count] > 0
    assert recipe[:missing_ingredients_count] >= 0
    assert recipe[:ingredients].is_a?(Array)
  end
end
