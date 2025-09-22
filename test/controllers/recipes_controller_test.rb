require "test_helper"

class RecipesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_url
    assert_response :success
  end

  test "should get match_ingredients" do
    get recipes_match_ingredients_url, as: :json
    assert_response :success
  end

  test "should get match_ingredients with ingredient_ids parameter" do
    get recipes_match_ingredients_url, params: { ingredient_ids: [ 1, 2 ] }, as: :json
    assert_response :success
  end

  test "should get match_ingredients with pagination" do
    get recipes_match_ingredients_url, params: { ingredient_ids: [ 1, 2 ], page: 1 }, as: :json
    assert_response :success
  end
end
