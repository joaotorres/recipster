require "rails_helper"

RSpec.describe IngredientsController, type: :controller do
  describe "GET #search" do
    context "with valid query" do
      let!(:salt) { Ingredient.create!(name: "salt") }
      let!(:sugar) { Ingredient.create!(name: "sugar") }

      it "returns successful response" do
        get :search, params: { q: "salt" }, format: :json
        expect(response).to have_http_status(:success)
      end

      it "returns JSON format" do
        get :search, params: { q: "salt" }, format: :json
        expect(response.content_type).to include("application/json")
      end

      it "returns ingredients matching the query" do
        get :search, params: { q: "salt" }, format: :json
        json_response = JSON.parse(response.body)
        expect(json_response).to be_an(Array)
        expect(json_response.first["name"]).to eq("salt")
      end

      it "uses IngredientSearchService" do
        expect(IngredientSearchService).to receive(:new).with("salt").and_call_original
        get :search, params: { q: "salt" }, format: :json
      end
    end

    context "with blank query" do
      it "returns empty array for empty string" do
        get :search, params: { q: "" }, format: :json
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response).to eq([])
      end

      it "returns empty array for nil query" do
        get :search, params: {}, format: :json
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response).to eq([])
      end
    end

    context "with HTML format request" do
      it "returns not acceptable" do
        get :search, params: { q: "salt" }
        expect(response).to have_http_status(:not_acceptable)
      end
    end

    context "with edge cases" do
      it "handles special characters" do
        get :search, params: { q: "salt!" }, format: :json
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response).to be_an(Array)
      end

      it "handles unicode characters" do
        get :search, params: { q: "café" }, format: :json
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response).to be_an(Array)
      end

      it "handles very long queries" do
        long_query = "a" * 1000
        get :search, params: { q: long_query }, format: :json
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response).to be_an(Array)
      end
    end
  end
end
