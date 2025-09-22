require "rails_helper"

RSpec.describe IngredientSearchService do
  let(:salt) { Ingredient.create!(name: "salt") }
  let(:sugar) { Ingredient.create!(name: "sugar") }
  let(:white_sugar) { Ingredient.create!(name: "white sugar") }
  let(:brown_sugar) { Ingredient.create!(name: "brown sugar") }
  let(:garlic) { Ingredient.create!(name: "garlic") }
  let(:garlic_powder) { Ingredient.create!(name: "garlic powder") }
  let(:onion) { Ingredient.create!(name: "onion") }
  let(:onion_powder) { Ingredient.create!(name: "onion powder") }

  before do
    # Ensure ingredients are created
    salt
    sugar
    white_sugar
    brown_sugar
    garlic
    garlic_powder
    onion
    onion_powder
  end

  describe "#call" do
    context "with blank query" do
      it "returns empty array for empty string" do
        service = described_class.new("")
        expect(service.call).to eq([])
      end

      it "returns empty array for nil query" do
        service = described_class.new(nil)
        expect(service.call).to eq([])
      end

      it "returns empty array for query with only spaces" do
        service = described_class.new("   ")
        expect(service.call).to eq([])
      end
    end

    context "with valid query" do
      it "finds ingredients starting with query" do
        service = described_class.new("salt")
        expect(service.call).to include(salt)
      end

      it "finds ingredients containing query" do
        service = described_class.new("garlic")
        expect(service.call).to include(garlic, garlic_powder)
      end

      it "prioritizes ingredients starting with query" do
        service = described_class.new("sugar")
        result = service.call

        sugar_index = result.index { |ing| ing.name == "sugar" }
        white_sugar_index = result.index { |ing| ing.name == "white sugar" }
        brown_sugar_index = result.index { |ing| ing.name == "brown sugar" }

        expect(sugar_index).not_to be_nil
        expect(white_sugar_index).not_to be_nil
        expect(brown_sugar_index).not_to be_nil
        expect(sugar_index).to be < white_sugar_index
        expect(sugar_index).to be < brown_sugar_index
      end

      it "prioritizes starts_with over contains" do
        service = described_class.new("garlic")
        result = service.call

        garlic_index = result.index { |ing| ing.name == "garlic" }
        garlic_powder_index = result.index { |ing| ing.name == "garlic powder" }

        expect(garlic_index).not_to be_nil
        expect(garlic_powder_index).not_to be_nil
        expect(garlic_index).to be < garlic_powder_index
      end

      it "orders by name length for starts_with results" do
        service = described_class.new("onion")
        result = service.call

        onion_index = result.index { |ing| ing.name == "onion" }
        onion_powder_index = result.index { |ing| ing.name == "onion powder" }

        expect(onion_index).not_to be_nil
        expect(onion_powder_index).not_to be_nil
        expect(onion_index).to be < onion_powder_index
      end

      it "is case insensitive" do
        service = described_class.new("SALT")
        expect(service.call).to include(salt)
      end

      it "handles queries with spaces" do
        service = described_class.new("white sugar")
        expect(service.call).to include(white_sugar)
      end

      it "handles queries with multiple spaces" do
        service = described_class.new("  white  sugar  ")
        expect(service.call).to include(white_sugar)
      end
    end

    context "with edge cases" do
      it "handles special characters in query" do
        service = described_class.new("salt!")
        result = service.call
        expect(result).to be_a(Array)
      end

      it "handles very long queries" do
        long_query = "a" * 1000
        service = described_class.new(long_query)
        result = service.call
        expect(result).to be_a(Array)
      end

      it "handles unicode characters" do
        service = described_class.new("café")
        result = service.call
        expect(result).to be_a(Array)
      end
    end

    context "with performance constraints" do
      it "limits results to MAX_RESULTS" do
        # Create more than MAX_RESULTS ingredients
        (1..35).each do |i|
          Ingredient.create!(name: "ingredient#{i}")
        end

        service = described_class.new("ingredient")
        result = service.call
        expect(result.length).to eq(IngredientSearchService::MAX_RESULTS)
      end

      it "returns unique results" do
        service = described_class.new("salt")
        result = service.call
        expect(result).to eq(result.uniq)
      end
    end

    context "with consistency" do
      it "maintains order consistency across multiple calls" do
        service = described_class.new("sugar")
        result1 = service.call
        result2 = service.call

        expect(result1).to eq(result2)
      end
    end
  end

  describe "#initialize" do
    it "normalizes query input" do
      service = described_class.new("  WHITE  SUGAR  ")
      expect(service.instance_variable_get(:@query)).to eq("white sugar")
    end

    it "handles nil input gracefully" do
      service = described_class.new(nil)
      expect(service.instance_variable_get(:@query)).to be_nil
    end
  end
end
