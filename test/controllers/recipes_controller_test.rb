require "test_helper"

class RecipesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_url
    assert_response :success
  end

  test "should get search without parameters" do
    get recipes_search_url, as: :json
    assert_response :success
  end

  test "should get search with ingredient_ids parameter" do
    get recipes_search_url, params: { ingredient_ids: [ 1, 2 ] }, as: :json
    assert_response :success
  end

  test "should get search with pagination" do
    get recipes_search_url, params: { ingredient_ids: [ 1, 2 ], page: 1 }, as: :json
    assert_response :success
  end

  test "should get search with name filter" do
    get recipes_search_url, params: { name: "pasta" }, as: :json
    assert_response :success
  end

  test "should get search with rating filter" do
    get recipes_search_url, params: { min_rating: 4.0 }, as: :json
    assert_response :success
  end

  test "should get search with time filter" do
    get recipes_search_url, params: { max_time: 30 }, as: :json
    assert_response :success
  end

  test "should get search with category filter" do
    get recipes_search_url, params: { category: "main-course" }, as: :json
    assert_response :success
  end

  test "should get search with multiple filters" do
    get recipes_search_url, params: {
      ingredient_ids: [ 1, 2 ],
      name: "pasta",
      min_rating: 4.0,
      max_time: 30,
      category: "main-course",
      page: 1
    }, as: :json
    assert_response :success
  end
end
