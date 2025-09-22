require 'rails_helper'

RSpec.describe ImportRecipes, 'Integration Tests', type: :model do
  describe '.extract_ingredients' do
    it 'extracts and cleans ingredients from an array' do
      ingredients_array = [
        '1 cup all-purpose flour',
        '1 cup yellow cornmeal',
        '⅔ cup white sugar',
        '1 teaspoon salt',
        '3 ½ teaspoons baking powder',
        '1 egg',
        '1 cup milk',
        '⅓ cup vegetable oil'
      ]

      result = ImportRecipes.send(:extract_ingredients, ingredients_array)

      expect(result).to include('all-purpose flour', 'yellow cornmeal', 'white sugar', 'baking powder', 'egg', 'milk', 'vegetable oil')
      expect(result.length).to eq(7)
    end

    it 'handles empty or invalid input' do
      expect(ImportRecipes.send(:extract_ingredients, [])).to eq([])
      expect(ImportRecipes.send(:extract_ingredients, nil)).to eq([])
      expect(ImportRecipes.send(:extract_ingredients, 'not an array')).to eq([])
    end

    it 'removes duplicates and nil values' do
      ingredients_array = [
        '1 cup all-purpose flour',
        'all-purpose flour',
        '1 cup all-purpose flour',
        '2g',  # This should become nil and be filtered out
        '1 cup all-purpose flour'
      ]

      result = ImportRecipes.send(:extract_ingredients, ingredients_array)

      expect(result).to eq([ 'all-purpose flour' ])
    end

    it 'handles complex ingredient descriptions' do
      ingredients_array = [
        '3 (12 ounce) packages refrigerated biscuit dough',
        '1 cup white sugar',
        '2 teaspoons ground cinnamon',
        '½ cup margarine',
        '1 cup packed brown sugar',
        '½ cup chopped walnuts',
        '½ cup raisins'
      ]

      result = ImportRecipes.send(:extract_ingredients, ingredients_array)

      expect(result).to include('biscuit dough', 'white sugar', 'ground cinnamon', 'margarine', 'packed brown sugar', 'walnut', 'raisin')
      expect(result.length).to eq(7)
    end

    it 'handles fractions and measurements correctly' do
      ingredients_array = [
        '1 ½ cups all-purpose flour',
        '1 ½ cups whole wheat flour',
        '4 ½ teaspoons baking powder',
        '1 ½ teaspoons salt',
        '⅓ cup packed brown sugar'
      ]

      result = ImportRecipes.send(:extract_ingredients, ingredients_array)

      expect(result).to include('all-purpose flour', 'wheat flour', 'baking powder', 'packed brown sugar')
      expect(result.length).to eq(4)
    end

    it 'removes descriptive words correctly' do
      ingredients_array = [
        '1 cup chopped fresh cilantro',
        '2 tablespoons olive oil, divided',
        '1 (15 ounce) can chickpeas, drained and rinsed',
        '¾ onion, diced',
        '¼ cup packed chopped fresh parsley'
      ]

      result = ImportRecipes.send(:extract_ingredients, ingredients_array)

      expect(result).to include('cilantro', 'olive oil', 'chickpea', 'onion', 'packedfresh parsley')
      expect(result.length).to eq(5)
    end

    it 'handles parentheses content correctly' do
      ingredients_array = [
        '1 (15 ounce) can chickpeas, drained and rinsed',
        '2 tablespoons olive oil, divided',
        '1 cup packed brown sugar'
      ]

      result = ImportRecipes.send(:extract_ingredients, ingredients_array)

      expect(result).to include('chickpea', 'olive oil', 'packed brown sugar')
      expect(result.length).to eq(3)
    end
  end

  describe '.process_recipe' do
    let(:sample_recipe_data) do
      {
        'title' => 'Golden Sweet Cornbread',
        'ingredients' => [
          '1 cup all-purpose flour',
          '1 cup yellow cornmeal',
          '⅔ cup white sugar',
          '1 teaspoon salt',
          '3 ½ teaspoons baking powder',
          '1 egg',
          '1 cup milk',
          '⅓ cup vegetable oil'
        ]
      }
    end

    before do
      # Clean up any existing test data
      Recipe.where(name: 'Golden Sweet Cornbread').destroy_all
      Ingredient.where(name: [ 'all-purpose flour', 'yellow cornmeal', 'white sugar', 'salt', 'baking powder', 'egg', 'milk', 'vegetable oil' ]).destroy_all
    end

    it 'creates a recipe with cleaned ingredients' do
      recipe = ImportRecipes.process_recipe(sample_recipe_data)

      expect(recipe).to be_persisted
      expect(recipe.name).to eq('Golden Sweet Cornbread')
      expect(recipe.ingredient_count).to eq(7)
      expect(recipe.ingredients.count).to eq(7)

      ingredient_names = recipe.ingredients.pluck(:name)
      expect(ingredient_names).to include('all-purpose flour', 'yellow cornmeal', 'white sugar', 'baking powder', 'egg', 'milk', 'vegetable oil')
    end

    it 'updates existing recipe when called again' do
      # Create initial recipe
      ImportRecipes.process_recipe(sample_recipe_data)

      # Update with new ingredients
      updated_recipe_data = sample_recipe_data.dup
      updated_recipe_data['ingredients'] = [ '1 cup flour', '2 eggs', '1 teaspoon salt' ]

      recipe = ImportRecipes.process_recipe(updated_recipe_data)

      expect(recipe.name).to eq('Golden Sweet Cornbread')
      expect(recipe.ingredient_count).to eq(2)
      expect(recipe.ingredients.count).to eq(2)

      ingredient_names = recipe.ingredients.pluck(:name)
      expect(ingredient_names).to include('flour', 'egg')
      expect(ingredient_names).not_to include('all-purpose flour', 'yellow cornmeal', 'white sugar', 'baking powder', 'milk', 'vegetable oil')
    end

    it 'creates ingredient records in the database' do
      expect {
        ImportRecipes.process_recipe(sample_recipe_data)
      }.to change(Ingredient, :count).by(7)

      expect(Ingredient.where(name: 'all-purpose flour')).to exist
      expect(Ingredient.where(name: 'yellow cornmeal')).to exist
      expect(Ingredient.where(name: 'white sugar')).to exist
    end

    it 'reuses existing ingredient records' do
      # Create an ingredient first
      existing_ingredient = Ingredient.create!(name: 'all-purpose flour')

      expect {
        ImportRecipes.process_recipe(sample_recipe_data)
      }.to change(Ingredient, :count).by(6) # Only 6 new ingredients, all-purpose flour already exists

      recipe = Recipe.find_by(name: 'Golden Sweet Cornbread')
      expect(recipe.ingredients).to include(existing_ingredient)
    end

    it 'handles recipes with no valid ingredients' do
      recipe_data = {
        'title' => 'Empty Recipe',
        'ingredients' => [ '2g', '1cl', '' ] # All should be filtered out
      }

      recipe = ImportRecipes.process_recipe(recipe_data)

      expect(recipe.name).to eq('Empty Recipe')
      expect(recipe.ingredient_count).to eq(0) # 'cl' is now removed as a unit
      expect(recipe.ingredients.count).to eq(0)
    end

    it 'handles complex recipe with various ingredient types' do
      complex_recipe_data = {
        'title' => 'Monkey Bread I',
        'ingredients' => [
          '3 (12 ounce) packages refrigerated biscuit dough',
          '1 cup white sugar',
          '2 teaspoons ground cinnamon',
          '½ cup margarine',
          '1 cup packed brown sugar',
          '½ cup chopped walnuts',
          '½ cup raisins'
        ]
      }

      recipe = ImportRecipes.process_recipe(complex_recipe_data)

      expect(recipe.name).to eq('Monkey Bread I')
      expect(recipe.ingredient_count).to eq(7)

      ingredient_names = recipe.ingredients.pluck(:name)
      expect(ingredient_names).to include('biscuit dough', 'white sugar', 'ground cinnamon', 'margarine', 'packed brown sugar', 'walnut', 'raisin')
    end

    it 'handles Sausage Stir Fry with Bow Tie Pasta recipe correctly' do
      sausage_recipe_data = {
        'title' => 'Sausage Stir Fry with Bow Tie Pasta',
        'ingredients' => [
          '1 (16 ounce) package kielbasa sausage, cut into 1/4-inch slices',
          '1 (16 ounce) package farfalle (bow tie) pasta',
          '2 tablespoons olive oil',
          '1 onion, chopped',
          '4 small zucchini, cut into 1/4-inch slices',
          '1 (6 ounce) package baby portobello mushrooms, sliced',
          '1 red bell pepper, cut into strips',
          '3 cloves garlic, minced',
          '1 (15 ounce) can diced tomatoes',
          '1 (8 ounce) can tomato sauce',
          '1 (6 ounce) can tomato paste',
          '1 teaspoon basil',
          '1 teaspoon oregano',
          '½ teaspoon salt',
          '½ teaspoon ground black pepper',
          '¼ cup grated Parmesan cheese'
        ]
      }

      recipe = ImportRecipes.process_recipe(sausage_recipe_data)

      expect(recipe.name).to eq('Sausage Stir Fry with Bow Tie Pasta')
      expect(recipe.ingredient_count).to eq(15)

      ingredient_names = recipe.ingredients.pluck(:name)
      expect(ingredient_names).to include(
        'kielbasa sausage',
        'farfalle pastum',
        'olive oil',
        'onion',
        'zucchini',
        'baby portobello mushroom',
        'red bell pepper',
        'garlic',
        'tomato',
        'tomato sauce',
        'tomato paste',
        'basil',
        'oregano',
        'ground black pepper',
        'parmesan cheese'
      )
    end

    it 'handles Diner-Style Baked Potato Home Fries recipe correctly' do
      potato_recipe_data = {
        'title' => 'Diner-Style Baked Potato Home Fries',
        'ingredients' => [
          '2 large baking potatoes',
          '2 tablespoons butter',
          '¼ cup chopped onion',
          'salt and ground black pepper to taste'
        ]
      }

      recipe = ImportRecipes.process_recipe(potato_recipe_data)

      expect(recipe.name).to eq('Diner-Style Baked Potato Home Fries')
      expect(recipe.ingredient_count).to eq(3)

      ingredient_names = recipe.ingredients.pluck(:name)
      expect(ingredient_names).to include(
        'baking potato',
        'butter',
        'onion'
      )
    end
  end
end
