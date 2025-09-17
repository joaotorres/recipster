# frozen_string_literal: true

Kaminari.configure do |config|
  config.default_per_page = 20  # Show 20 recipes per page for infinite scroll
  config.max_per_page = 50      # Maximum 50 recipes per page
  config.window = 2             # Show 2 pages around current page
  config.outer_window = 1       # Show 1 page at the beginning/end
  config.left = 0
  config.right = 0
  config.page_method_name = :page
  config.param_name = :page
  config.max_pages = nil
  config.params_on_first_page = false
end
