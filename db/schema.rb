# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_17_132222) do
  create_table "ingredients", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "idx_ingredients_name"
  end

  create_table "ingredients_recipes", id: false, force: :cascade do |t|
    t.integer "recipe_id", null: false
    t.integer "ingredient_id", null: false
    t.index ["ingredient_id", "recipe_id"], name: "idx_ingredients_recipes_ingredient_recipe"
    t.index ["recipe_id", "ingredient_id"], name: "idx_ingredients_recipes_recipe_ingredient"
  end

  create_table "recipes", force: :cascade do |t|
    t.string "name"
    t.integer "ingredient_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ingredient_count"], name: "idx_recipes_ingredient_count"
  end
end
