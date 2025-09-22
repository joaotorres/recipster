require "rails_helper"

RSpec.describe RecipeSearchService do
  let!(:test_salt) { Ingredient.create!(name: "test_salt_#{SecureRandom.hex(4)}") }
  let!(:test_sugar) { Ingredient.create!(name: "test_sugar_#{SecureRandom.hex(4)}") }
  let!(:test_flour) { Ingredient.create!(name: "test_flour_#{SecureRandom.hex(4)}") }
  let!(:test_butter) { Ingredient.create!(name: "test_butter_#{SecureRandom.hex(4)}") }

  let!(:recipe1) do
    recipe = Recipe.create!(name: "Test Simple Cake", ingredient_count: 3)
    recipe.ingredients << [ test_salt, test_sugar, test_flour ]
    recipe
  end

  let!(:recipe2) do
    recipe = Recipe.create!(name: "Test Complex Cake", ingredient_count: 4)
    recipe.ingredients << [ test_salt, test_sugar, test_flour, test_butter ]
    recipe
  end

  let!(:recipe3) do
    recipe = Recipe.create!(name: "Test Salt Only", ingredient_count: 1)
    recipe.ingredients << test_salt
    recipe
  end

  describe "#call" do
    context "with valid ingredient IDs" do
      it "returns recipes matching the ingredients" do
        service = described_class.new([ test_salt.id, test_sugar.id ])
        result = service.call

        expect(result[:recipes].length).to eq(3)
        recipe_names = result[:recipes].map { |r| r[:name] }
        expect(recipe_names).to include("Test Simple Cake", "Test Complex Cake", "Test Salt Only")
      end

      it "orders recipes by missing ingredients count (ascending)" do
        service = described_class.new([ test_salt.id, test_sugar.id ])
        result = service.call

        # Test Salt Only has 0 missing ingredients (has both salt and sugar) - 1 matched, 1 total
        # Test Simple Cake has 1 missing ingredient (flour) - 2 matched, 3 total
        # Test Complex Cake has 2 missing ingredients (flour, butter) - 2 matched, 4 total
        expect(result[:recipes].first[:name]).to eq("Test Salt Only")
        expect(result[:recipes].second[:name]).to eq("Test Simple Cake")
        expect(result[:recipes].third[:name]).to eq("Test Complex Cake")
      end

      it "includes all recipe data" do
        service = described_class.new([ test_salt.id ])
        result = service.call

        recipe = result[:recipes].first
        expect(recipe).to include(
          :name,
          :ingredients,
          :matched_ingredients_count,
          :total_ingredients_count,
          :missing_ingredients_count
        )
      end

      it "calculates matched ingredients count correctly" do
        service = described_class.new([ test_salt.id, test_sugar.id ])
        result = service.call

        simple_cake = result[:recipes].find { |r| r[:name] == "Test Simple Cake" }
        expect(simple_cake[:matched_ingredients_count]).to eq(2)
        expect(simple_cake[:total_ingredients_count]).to eq(3)
        expect(simple_cake[:missing_ingredients_count]).to eq(1)
      end

      it "includes all ingredients, not just matched ones" do
        service = described_class.new([ test_salt.id ])
        result = service.call

        complex_cake = result[:recipes].find { |r| r[:name] == "Test Complex Cake" }
        expect(complex_cake[:ingredients]).to include(test_salt.name, test_sugar.name, test_flour.name, test_butter.name)
      end
    end

    context "with empty ingredient IDs" do
      it "returns empty result" do
        service = described_class.new([])
        result = service.call

        expect(result[:recipes]).to be_empty
        expect(result[:pagination][:total_count]).to eq(0)
      end

      it "returns empty result for nil ingredient IDs" do
        service = described_class.new(nil)
        result = service.call

        expect(result[:recipes]).to be_empty
        expect(result[:pagination][:total_count]).to eq(0)
      end
    end

    context "with pagination" do
      before do
        # Create more recipes to test pagination
        (1..25).each do |i|
          recipe = Recipe.create!(name: "Test Recipe #{i}", ingredient_count: 1)
          recipe.ingredients << test_salt
        end
      end

      it "respects page size" do
        service = described_class.new([ test_salt.id ], 1)
        result = service.call

        expect(result[:recipes].length).to eq(20) # 20 recipes per page
        expect(result[:pagination][:per_page]).to eq(20)
      end

      it "handles different pages" do
        service = described_class.new([ test_salt.id ], 2)
        result = service.call

        expect(result[:pagination][:current_page]).to eq(2)
        expect(result[:pagination][:has_prev_page]).to be true
      end

      it "includes pagination metadata" do
        service = described_class.new([ test_salt.id ], 1)
        result = service.call

        expect(result[:pagination]).to include(
          :current_page,
          :total_pages,
          :total_count,
          :per_page,
          :has_next_page,
          :has_prev_page
        )
      end
    end

    context "with non-existent ingredient IDs" do
      it "returns empty result" do
        service = described_class.new([ 999999 ])
        result = service.call

        expect(result[:recipes]).to be_empty
        expect(result[:pagination][:total_count]).to eq(0)
      end
    end

    context "with mixed valid and invalid ingredient IDs" do
      it "only considers valid ingredient IDs" do
        service = described_class.new([ test_salt.id, 999999 ])
        result = service.call

        expect(result[:recipes].length).to eq(3)
        recipe_names = result[:recipes].map { |r| r[:name] }
        expect(recipe_names).to include("Test Simple Cake", "Test Complex Cake", "Test Salt Only")
      end
    end
  end

  describe "#initialize" do
    it "handles string page parameter" do
      service = described_class.new([ test_salt.id ], "2")
      expect(service.instance_variable_get(:@page)).to eq(2)
    end

    it "handles nil page parameter" do
      service = described_class.new([ test_salt.id ], nil)
      expect(service.instance_variable_get(:@page)).to eq(1)
    end

    it "converts ingredient_ids to array" do
      service = described_class.new(test_salt.id)
      expect(service.instance_variable_get(:@ingredient_ids)).to eq([ test_salt.id ])
    end

    it "stores ingredient_ids and page" do
      service = described_class.new([ test_salt.id, test_sugar.id ], 2)

      expect(service.instance_variable_get(:@ingredient_ids)).to eq([ test_salt.id, test_sugar.id ])
      expect(service.instance_variable_get(:@page)).to eq(2)
    end
  end
end
