import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.setupAutocomplete()
    this.setupEventListeners()
  }

  setupAutocomplete() {
    this.input = this.element.querySelector('input[type="search"]')
    this.ingredientsList = document.getElementById('ingredients-list')
    this.recipesSection = document.getElementById('recipes-section')
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
    dropdown.className = 'suggestions-dropdown w-full bg-white border border-gray-300 rounded-lg shadow-lg max-h-60 overflow-y-auto'

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

    // Position dropdown relative to the input field
    const inputContainer = this.input.parentNode
    inputContainer.appendChild(dropdown)
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
    this.recipesSection.style.display = 'none'
    this.clearMessages()

    // Clear any existing autocomplete dropdown
    const existingSuggestions = document.querySelector('.suggestions-dropdown')
    if (existingSuggestions) {
      existingSuggestions.remove()
    }

    // Clear the input field
    if (this.input) {
      this.input.value = ''
    }
  }

  async searchRecipes() {
    const ingredients = Array.from(this.ingredientsList.querySelectorAll('[data-ingredient-id]'))
      .map(el => el.dataset.ingredientId)

    if (ingredients.length === 0) {
      this.recipesSection.style.display = 'none'
      this.clearMessages()
      return
    }

    // Start timing the search
    const searchStartTime = performance.now()

    // Show loading spinner
    this.showLoading()

    try {
      const params = new URLSearchParams()
      ingredients.forEach(id => params.append('ingredient_ids[]', id))

      const response = await fetch(`/ingredients/match_ingredients?${params}`)
      const recipes = await response.json()

      // Calculate search duration
      const searchEndTime = performance.now()
      const searchDuration = Math.round(searchEndTime - searchStartTime)

      this.hideLoading()
      this.displayRecipes(recipes)

      // Log search performance
      console.log(`🔍 Recipe search completed in ${searchDuration}ms - Found ${recipes.length} recipe${recipes.length === 1 ? '' : 's'} for ${ingredients.length} ingredient${ingredients.length === 1 ? '' : 's'}`)
    } catch (error) {
      // Calculate search duration even on error
      const searchEndTime = performance.now()
      const searchDuration = Math.round(searchEndTime - searchStartTime)

      console.error(`❌ Recipe search failed after ${searchDuration}ms:`, error)
      this.hideLoading()
      this.showMessage('Error searching for recipes. Please try again.', 'error')
    }
  }

  showLoading() {
    this.recipesSection.style.display = 'block'
    this.recipesSection.innerHTML = `
      <li class="flex items-center justify-center py-8">
        <div class="flex items-center space-x-2">
          <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600"></div>
          <span class="text-gray-600">Searching for recipes...</span>
        </div>
      </li>
    `
  }

  hideLoading() {
    // Loading will be replaced by displayRecipes or error message
  }

  displayRecipes(recipes) {
    if (recipes.length === 0) {
      this.recipesSection.style.display = 'none'
      return
    }

    // Show the recipes section and build the complete content with header
    this.recipesSection.style.display = 'block'

    // Create the header and recipes list
    let recipesHTML = `<h3 class="text-lg font-semibold mb-2">${recipes.length} Recipe${recipes.length === 1 ? '' : 's'} Found:</h3><ul class="space-y-2">`

    recipes.forEach(recipe => {
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

      recipesHTML += `
        <li class="p-4 bg-gray-50 rounded-lg border">
          <div class="flex justify-between items-start mb-2">
            <h4 class="font-semibold text-lg">${recipe.name}</h4>
            <div class="flex flex-wrap gap-1">
              ${totalBadge}
              ${matchedBadge}
              ${missingBadge}
            </div>
          </div>
          <p class="text-sm text-gray-600">Ingredients: ${recipe.ingredients.join(', ')}</p>
        </li>
      `
    })

    recipesHTML += '</ul>'
    this.recipesSection.innerHTML = recipesHTML
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

