require "rails_helper"

RSpec.describe RecipesController, type: :controller do
  let!(:salt) { Ingredient.create!(name: "salt") }
  let!(:sugar) { Ingredient.create!(name: "sugar") }
  let!(:flour) { Ingredient.create!(name: "flour") }

  let!(:recipe) do
    recipe = Recipe.create!(name: "Test Cake", ingredient_count: 3)
    recipe.ingredients << [ salt, sugar, flour ]
    recipe
  end

  describe "GET #index" do
    it "returns successful response" do
      get :index
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET #search" do
    context "with valid parameters" do
      it "returns successful response" do
        get :search, params: { ingredient_ids: [ salt.id ] }, format: :json
        expect(response).to have_http_status(:success)
      end

      it "returns JSON format" do
        get :search, params: { ingredient_ids: [ salt.id ] }, format: :json
        expect(response.content_type).to include("application/json")
      end

      it "returns recipes and pagination data" do
        get :search, params: { ingredient_ids: [ salt.id ] }, format: :json
        json_response = JSON.parse(response.body)

        expect(json_response).to have_key("recipes")
        expect(json_response).to have_key("pagination")
        expect(json_response["recipes"]).to be_an(Array)
      end

      it "uses RecipeSearchService with filters" do
        expect(RecipeSearchService).to receive(:new).with([ salt.id ], {}, 1).and_call_original
        get :search, params: { ingredient_ids: [ salt.id ] }, format: :json
      end

      it "passes page parameter to service" do
        expect(RecipeSearchService).to receive(:new).with([ salt.id ], {}, 2).and_call_original
        get :search, params: { ingredient_ids: [ salt.id ], page: "2" }, format: :json
      end
    end

    context "with name filter" do
      it "applies name filter" do
        get :search, params: { name: "cake" }, format: :json
        json_response = JSON.parse(response.body)

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key("recipes")
      end
    end

    context "with rating filter" do
      it "applies rating filter" do
        get :search, params: { min_rating: 4.0 }, format: :json
        json_response = JSON.parse(response.body)

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key("recipes")
      end
    end

    context "with time filter" do
      it "applies time filter" do
        get :search, params: { max_time: 30 }, format: :json
        json_response = JSON.parse(response.body)

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key("recipes")
      end
    end

    context "with category filter" do
      it "applies category filter" do
        get :search, params: { category: "dessert" }, format: :json
        json_response = JSON.parse(response.body)

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key("recipes")
      end
    end

    context "with multiple filters" do
      it "applies all filters together" do
        get :search, params: {
          ingredient_ids: [ salt.id ],
          name: "cake",
          min_rating: 4.0,
          max_time: 30,
          category: "dessert"
        }, format: :json
        json_response = JSON.parse(response.body)

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key("recipes")
      end
    end

    context "with empty ingredient_ids" do
      it "returns all recipes when no ingredient filter" do
        get :search, params: { ingredient_ids: [] }, format: :json
        json_response = JSON.parse(response.body)

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key("recipes")
      end

      it "returns successful response" do
        get :search, params: { ingredient_ids: [] }, format: :json
        expect(response).to have_http_status(:success)
      end
    end

    context "with no ingredient_ids parameter" do
      it "returns top-rated recipes" do
        get :search, format: :json
        json_response = JSON.parse(response.body)

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key("recipes")
        expect(json_response["recipes"]).to be_an(Array)
      end
    end

    context "with HTML format request" do
      it "returns not acceptable" do
        get :search, params: { ingredient_ids: [ salt.id ] }
        expect(response).to have_http_status(:not_acceptable)
      end
    end

    context "with edge cases" do
      it "handles non-existent ingredient IDs" do
        get :search, params: { ingredient_ids: [ 999999 ] }, format: :json
        json_response = JSON.parse(response.body)

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key("recipes")
      end

      it "handles invalid page parameter" do
        get :search, params: { ingredient_ids: [ salt.id ], page: "invalid" }, format: :json
        expect(response).to have_http_status(:success)
      end

      it "handles very large page numbers" do
        get :search, params: { ingredient_ids: [ salt.id ], page: 999999 }, format: :json
        expect(response).to have_http_status(:success)
      end
    end

    context "with multiple ingredient IDs" do
      it "finds recipes matching ingredients" do
        get :search, params: { ingredient_ids: [ salt.id, sugar.id ] }, format: :json
        json_response = JSON.parse(response.body)

        expect(response).to have_http_status(:success)
        expect(json_response["recipes"]).not_to be_empty
        recipe_names = json_response["recipes"].map { |r| r["name"] }
        expect(recipe_names).to include("Test Cake")
      end
    end
  end
end
