import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.setupAutocomplete()
    this.setupEventListeners()
  }

  setupAutocomplete() {
    this.input = this.element
    this.ingredientsList = document.getElementById('ingredients-list')
    this.recipesList = document.getElementById('recipes-list')
    this.messagesDiv = document.getElementById('messages')

    // Simple debounced search
    this.searchTimeout = null
    this.input.addEventListener('input', (e) => {
      clearTimeout(this.searchTimeout)
      this.searchTimeout = setTimeout(() => {
        this.searchIngredients(e.target.value)
      }, 300)
    })
  }

  setupEventListeners() {
    // Clear ingredients button
    document.getElementById('clear-ingredients').addEventListener('click', () => {
      this.clearIngredients()
    })
  }

  async searchIngredients(query) {
    if (query.length < 2) return

    try {
      const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`)
      const ingredients = await response.json()
      this.showSuggestions(ingredients)
    } catch (error) {
      console.error('Search error:', error)
    }
  }

  showSuggestions(ingredients) {
    // Remove existing suggestions
    const existingSuggestions = document.querySelector('.suggestions-dropdown')
    if (existingSuggestions) {
      existingSuggestions.remove()
    }

    if (ingredients.length === 0) return

    // Create suggestions dropdown
    const dropdown = document.createElement('div')
    dropdown.className = 'suggestions-dropdown absolute z-10 w-full bg-white border border-gray-300 rounded-lg shadow-lg mt-1 max-h-60 overflow-y-auto'

    ingredients.forEach(ingredient => {
      const item = document.createElement('div')
      item.className = 'px-4 py-2 hover:bg-gray-100 cursor-pointer border-b border-gray-100 last:border-b-0'
      item.textContent = ingredient.name
      item.dataset.ingredientId = ingredient.id
      item.dataset.ingredientName = ingredient.name

      item.addEventListener('click', () => {
        this.addIngredient(ingredient.id, ingredient.name)
        this.input.value = ''
        dropdown.remove()
      })

      dropdown.appendChild(item)
    })

    // Position dropdown
    this.input.parentNode.style.position = 'relative'
    this.input.parentNode.appendChild(dropdown)
  }

  addIngredient(id, name) {
    // Check if ingredient already exists
    const existing = this.ingredientsList.querySelector(`[data-ingredient-id="${id}"]`)
    if (existing) return

    // Create ingredient chip
    const chip = document.createElement('div')
    chip.className = 'inline-flex items-center gap-2 px-3 py-1 bg-blue-100 text-blue-800 rounded-full text-sm'
    chip.dataset.ingredientId = id
    chip.innerHTML = `
      <span>${name}</span>
      <button class="ml-1 text-blue-600 hover:text-blue-800" data-action="click->ingredient-search#removeIngredient">
        ×
      </button>
    `

    this.ingredientsList.appendChild(chip)
    this.clearMessages()

    // Automatically search for recipes when ingredient is added
    this.searchRecipes()
  }

  removeIngredient(event) {
    event.target.closest('[data-ingredient-id]').remove()

    // Automatically search for recipes when ingredient is removed
    this.searchRecipes()
  }

  clearIngredients() {
    this.ingredientsList.innerHTML = ''
    this.recipesList.innerHTML = ''
    this.clearMessages()
  }

  async searchRecipes() {
    const ingredients = Array.from(this.ingredientsList.querySelectorAll('[data-ingredient-id]'))
      .map(el => el.dataset.ingredientId)

    if (ingredients.length === 0) {
      this.showMessage('Please add some ingredients first!', 'error')
      return
    }

    try {
      const params = new URLSearchParams()
      ingredients.forEach(id => params.append('ingredient_ids[]', id))

      const response = await fetch(`/ingredients/match_ingredients?${params}`)
      const recipes = await response.json()

      this.displayRecipes(recipes)
    } catch (error) {
      console.error('Recipe search error:', error)
      this.showMessage('Error searching for recipes. Please try again.', 'error')
    }
  }

  displayRecipes(recipes) {
    this.recipesList.innerHTML = ''

    if (recipes.length === 0) {
      this.recipesList.innerHTML = '<li class="text-gray-500 italic">No recipes found with these ingredients.</li>'
      return
    }

    recipes.forEach(recipe => {
      const recipeItem = document.createElement('li')
      recipeItem.className = 'p-4 bg-gray-50 rounded-lg border'

      // Create ingredient count badges
      const totalBadge = `<span class="inline-block bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded-full mr-2">${recipe.total_ingredients_count} ingredients</span>`

      let matchedBadge, missingBadge

      if (recipe.missing_ingredients_count === 0) {
        // All ingredients are available - show "All in the fridge" in green
        matchedBadge = `<span class="inline-block bg-green-100 text-green-800 text-xs px-2 py-1 rounded-full mr-2">✓ All in the fridge</span>`
        missingBadge = '' // Don't show missing badge when there are no missing ingredients
      } else {
        // Some ingredients are missing - show "X in the fridge" in yellow and missing count
        matchedBadge = `<span class="inline-block bg-yellow-100 text-yellow-800 text-xs px-2 py-1 rounded-full mr-2">✓ ${recipe.matched_ingredients_count} in the fridge</span>`
        missingBadge = `<span class="inline-block bg-orange-100 text-orange-800 text-xs px-2 py-1 rounded-full">⚠ ${recipe.missing_ingredients_count} missing</span>`
      }

      recipeItem.innerHTML = `
        <div class="flex justify-between items-start mb-2">
          <h4 class="font-semibold text-lg">${recipe.name}</h4>
          <div class="flex flex-wrap gap-1">
            ${totalBadge}
            ${matchedBadge}
            ${missingBadge}
          </div>
        </div>
        <p class="text-sm text-gray-600">Ingredients: ${recipe.ingredients.join(', ')}</p>
      `
      this.recipesList.appendChild(recipeItem)
    })
  }

  showMessage(message, type = 'info') {
    this.messagesDiv.innerHTML = `
      <div class="p-3 rounded-lg ${type === 'error' ? 'bg-red-100 text-red-800' : 'bg-blue-100 text-blue-800'}">
        ${message}
      </div>
    `
  }

  clearMessages() {
    this.messagesDiv.innerHTML = ''
  }
}

