# Recipster: find recipes that you can cook with the ingredients you have

This repository contains a Rails app that implements a solution to the Pennylane technical test described on the [problem_statement.md](./problem_statement.md) file on the top folder of this repository.

It's implemented using Rails 8 with Hotwire, Stimulus and Tailwind.

It uses the recipe data provided and implements a website / app that allows users to "find the most relevant recipes that they can prepare with the ingredients that they have at home".

The app is live at https://recipster.up.railway.app/

The rest of this document contains a description of the implemented user stories, some project design decisions and usage instructions.

## Index

- [User Stories](#user-stories)
  - [1. Recipe search by name](#1-recipe-search-by-name)
  - [2. Ingredient entry](#2-ingredient-entry)
  - [3. Filtering recipes](#3-filtering-recipes)
- [Other project decisions](#other-project-decisions)
  - [Only desktop, no mobile](#only-desktop-no-mobile)
  - [Recipe and ingredient data normalization](#recipe-and-ingredient-data-normalization)
  - [Recipe and Ingredient search and ranking reasoning](#recipe-and-ingredient-search-and-ranking-reasoning)
  - [Search UI/UX reasoning](#search-uiux-reasoning)
  - [Show "Top Recipes" when you open the page](#show-top-recipes-when-you-open-the-page)
  - [There's no "recipe page" or "recipe details"](#theres-no-recipe-page-or-recipe-details)
- [Usage instructions](#usage-instructions)


## User Stories

After considering the problem statement and doing some research I decided to implement the 3 following user stories, with the associated acceptance criteria:

### 1. Recipe search by name
**As a user, I want to search for recipes by name, so that I can quickly locate a specific dish or narrow down my options.**

**Acceptance Criteria**
- A search input is available for entering part or all of a recipe name.
- Search results include recipes whose names contain all the words entered (case-insensitive and in any order).
- If no recipes match, a “No recipes found” message is shown.
- If no ingredients are selected, search among all recipes.
- If no ingredients are added and there's no search query or filters, show the 20 highest rated recipes as "Top Recipes".
- If ingredients are selected, search only among the recipes that contain at least one of the selected ingredients.

### 2. Ingredient entry
**As a user, I want to enter the ingredients I have at home, so that I can find recipe suggestions based on what’s available.**

**Acceptance Criteria**
- The user can add ingredients by typing their names in a text field with autocomplete.
- The application should already assume the user has water, salt and pepper (so they don't have to enter it manually and they don't affect the recipe results).
- The user can add ingredients with one click from a predefined list (e.g. “Common Ingredients”).
- The user can remove individual ingredients from the selected list.
- The user can clear all selected ingredients at once.
- When the list of selected ingredients is updated, the recipe suggestions automatically update to show all recipes that include at least one of them.
- The results should be ordered by these criteria in order of priority: number of ingredients missing (descending), number of ingredients present (ascending), recipe rating (descending)

### 3. Filtering recipes
**As a user, I want to apply filters for cooking time, rating, and category, so that I can refine the recipe suggestions to match my preferences.**

**Acceptance Criteria**
- The user can set a maximum cooking time filter.
- The user can set a minimum rating filter.
- The user can select a recipe category from a drop down menu.
- The user can clear all filters with a single action.
- Recipe results update automatically when filters are applied.
- If no recipes match the applied filters, a “No recipes found” message is shown.
- If no ingredients are selected, search among all recipes.
- If ingredients are selected, search only among the recipes that contain at least one of the selected ingredients.

## Other project decisions

### Only desktop, no mobile

Considering the problem statement and other requirements, I decided to optimize the app only for the Desktop and not mobile. Though in a "real" scenario an app like this would certainly benefit from having a working mobile version, as this is an exercise for a backend position, I figured it wasn't particularly necessary at this point.

### Recipe and ingredient data normalization

Processing the recipe and normalizing ingredient data was an important part of the work. Though I did put some effort into that, I understand there's a fair amount of edge cases that were not treated for the sake of time.

### Recipe and Ingredient search and ranking reasoning

I understand that the core feature of this app is the ingredient-based search, though I had to combine it with a possibility of a regular name-based recipe search.

The solution I settled for was that if you add any ingredients, your search space becomes all the recipes that contain at least one of these ingredients, and then the search by name and other filters then filter the results from this search space. On the other hand, if you don't add any ingredients, the search space is all the recipes in the DB.

I understood that the search results should prioritize recipes for which you had all the ingredients, so that was the first criteria for ranking the results. I'd first order the recipes by the number of ingredients missing in ascending order, so that first you'd see "complete" recipes, then the ones missing 1 ingredient and so on. As a second ranking criteria I then use the number of ingredients that you have that are in the recipe in descending order (starting by the ones you have more ingredients) and finally I'd use the recipe rating in descending order.

### Search UI/UX reasoning

I consciously decided to use 3 different behaviors for the the ingredient search, the recipe search and the recipe category selection.

### 1. Ingredients

For the ingredients serach I believe auto-complete made the most sense as I wanted to make entering a lot of ingredients both easy and accurate but ultimately match it with ingredients that are on the DB.

I figured it made sense to exclude some ingredients from the search space, as for example "water" is something that absolutely didn't make sense to use in the matching process. And once we were already excluding water I figured I should likely add some more and I settled for also excluding salt and pepper.

I also made possible to 1-click add the ingredients that appeared in the most recipes, as the real value from using this app would come from having a comprehensive list of ingredients, but I found it would be tedious to have to manually type a lot of ingredients by hand.

Also, the recipe display shows the ingredient list in a color-coded manner so that you see the ingredients that you have or that you're missing and you can toggle them by clicking at them.

### 2. Recipes

For the top search bar for recipe names, I think it was a trickier decision as auto-complete wouldn't really make sense. There you don't want to match just one recipe but find several recipes that match whatever the user might be searching. I understand that here there's also space for improvement with both fancier search and ranking, but as in a way the main focus of the app was the recipe search based on ingredients that you have, I just made it so that the recipes found should include the words search in their name.

### 3. Categories

Finally for the category selection I chose to put them on a drop down and included just the more common categories for simplicity sake. Here maybe an autocomplete and allowing for multiple options could make sense, but I thought it might overcomplicate the UI and put more emphasis on the category filter which wasn't desirable.

### Show "Top Recipes" when you open the page

I figured that when you open the page it made more sense to already show some recipes than to just show a blank page. I decided to show the top rated recipes which in a real case could be replaced with, for example, the user's starred or higher rated recipes. Showing some recipes even before the user searches anything also synergizes with you being able to add ingredients directly from the ingredient list of the recipe.

### There's no "recipe page" or "recipe details"

In a real app you'd need to show the details of the recipe, not only the actual cooking instructions but also a list of the ingredients with their measuring units, but as we were not really provided with more information from the recipes I chose not to implement a "recipe page" and the full ingredient list with measurements is also not shown.

## Usage instructions

### Prerequisites

- Ruby/Rails toolchain (for local runs without Docker) or Docker (for containerized runs)
- Rails credentials master key
  - If you already have one, ensure it exists at `config/master.key` (do NOT commit it), or export it via `RAILS_MASTER_KEY` when running
  - If you don’t have one yet, generate credentials (this creates `config/master.key` and updates `config/credentials.yml.enc`):

```bash
bin/rails credentials:edit
# Do NOT commit config/master.key
```

### Run with Docker

Build the image and run the app on http://localhost:3000:

```bash
docker build -t recipster .
docker run --rm -p 3000:80 \
  -e RAILS_MASTER_KEY="$(cat config/master.key)" \
  --name recipster recipster
```

Optional: persist local volumes (DB, storage, logs):

```bash
docker run --rm -p 3000:80 \
  -e RAILS_MASTER_KEY="$(cat config/master.key)" \
  -v "$PWD/db:/rails/db" \
  -v "$PWD/storage:/rails/storage" \
  -v "$PWD/log:/rails/log" \
  --name recipster recipster
```

### Run locally (without Docker)

```bash
export RAILS_MASTER_KEY="$(cat config/master.key)"  # or set in your shell profile
bin/rails db:prepare
bin/rails server
# Visit http://localhost:3000
```
