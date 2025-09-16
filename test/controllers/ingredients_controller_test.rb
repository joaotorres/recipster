require "test_helper"

class IngredientsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get ingredients_index_url
    assert_response :success
  end

  test "should get search" do
    get ingredients_search_url
    assert_response :success
  end

  test "should get match_ingredients" do
    get ingredients_match_ingredients_url
    assert_response :success
  end
end
