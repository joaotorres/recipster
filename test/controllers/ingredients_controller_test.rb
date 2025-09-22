require "test_helper"

class IngredientsControllerTest < ActionDispatch::IntegrationTest
  test "should get search" do
    get ingredients_search_url
    assert_response :success
  end
end
