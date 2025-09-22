import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.setupAutocomplete()
    this.setupEventListeners()
    this.setupInfiniteScroll()

    // Initialize pagination state
    this.currentPage = 1
    this.totalPages = 1
    this.totalCount = 0
    this.isLoading = false
    this.allRecipes = []
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

    // Handle Esc key to close autocomplete
    this.input.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        this.hideSuggestions()
        this.input.blur() // Remove focus from input
      }
    })

    // Handle clicks outside the dropdown to close it
    document.addEventListener('click', (e) => {
      const dropdown = document.querySelector('.suggestions-dropdown')
      if (dropdown && !this.input.contains(e.target) && !dropdown.contains(e.target)) {
        this.hideSuggestions()
      }
    })
  }

  setupEventListeners() {
    // Clear ingredients button
    document.getElementById('clear-ingredients').addEventListener('click', () => {
      this.clearIngredients()
    })
  }

  setupInfiniteScroll() {
    // Create intersection observer for infinite scroll
    this.observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting && !this.isLoading && this.currentPage < this.totalPages) {
          this.loadMoreRecipes()
        }
      })
    }, {
      rootMargin: '100px' // Load more when 100px before reaching the bottom
    })
  }

  async searchIngredients(query) {
    if (query.length < 1) return

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

  hideSuggestions() {
    const existingSuggestions = document.querySelector('.suggestions-dropdown')
    if (existingSuggestions) {
      existingSuggestions.remove()
    }
  }

  addIngredient(id, name) {
    // Check if ingredient already exists
    const existing = this.ingredientsList.querySelector(`[data-ingredient-id="${id}"]`)
    if (existing) return

    // Create ingredient chip
    const chip = document.createElement('div')
    chip.className = 'inline-flex items-center gap-2 px-3 py-1 bg-green-100 text-green-800 rounded-full text-sm'
    chip.dataset.ingredientId = id
    chip.dataset.ingredientName = name
    chip.innerHTML = `
      <span>${name}</span>
      <button class="ml-1 text-green-600 hover:text-green-800" data-action="click->ingredient-search#removeIngredient">
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

  removeIngredientFromRecipe(event) {
    const ingredientId = event.target.closest('[data-ingredient-id]').dataset.ingredientId
    const ingredientElement = this.ingredientsList.querySelector(`[data-ingredient-id="${ingredientId}"]`)

    if (ingredientElement) {
      ingredientElement.remove()
      this.searchRecipes()
    }
  }

  addIngredientFromRecipe(event) {
    const ingredientName = event.target.closest('[data-ingredient-name]').dataset.ingredientName

    // Check if ingredient already exists
    const existing = Array.from(this.ingredientsList.querySelectorAll('[data-ingredient-name]'))
      .find(el => el.dataset.ingredientName.toLowerCase() === ingredientName.toLowerCase())

    if (existing) return

    // We need to find the ingredient ID by searching for it
    this.searchIngredientByName(ingredientName)
  }

  async searchIngredientByName(ingredientName) {
    try {
      const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(ingredientName)}`)
      const ingredients = await response.json()

      // Find exact match (case insensitive)
      const exactMatch = ingredients.find(ingredient =>
        ingredient.name.toLowerCase() === ingredientName.toLowerCase()
      )

      if (exactMatch) {
        this.addIngredient(exactMatch.id, exactMatch.name)
      } else {
        console.warn(`Ingredient "${ingredientName}" not found in search results`)
      }
    } catch (error) {
      console.error('Error searching for ingredient:', error)
    }
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
      this.resetPagination()
      return
    }

    // Reset pagination for new search
    this.resetPagination()

    // Start timing the search
    const searchStartTime = performance.now()

    // Show loading spinner
    this.showLoading()

    try {
      const response = await this.fetchRecipes(ingredients, 1)
      const data = await response.json()

      // Calculate search duration
      const searchEndTime = performance.now()
      const searchDuration = Math.round(searchEndTime - searchStartTime)

      this.hideLoading()
      this.displayRecipes(data.recipes, data.pagination, true)

      // Log search performance
      console.log(`🔍 Recipe search completed in ${searchDuration}ms - Found ${data.pagination.total_count} recipe${data.pagination.total_count === 1 ? '' : 's'} for ${ingredients.length} ingredient${ingredients.length === 1 ? '' : 's'}`)
    } catch (error) {
      // Calculate search duration even on error
      const searchEndTime = performance.now()
      const searchDuration = Math.round(searchEndTime - searchStartTime)

      console.error(`❌ Recipe search failed after ${searchDuration}ms:`, error)
      this.hideLoading()
      this.showMessage('Error searching for recipes. Please try again.', 'error')
    }
  }

  async loadMoreRecipes() {
    if (this.isLoading || this.currentPage >= this.totalPages) return

    this.isLoading = true
    this.currentPage++

    const ingredients = Array.from(this.ingredientsList.querySelectorAll('[data-ingredient-id]'))
      .map(el => el.dataset.ingredientId)

    try {
      const response = await this.fetchRecipes(ingredients, this.currentPage)
      const data = await response.json()

      this.displayRecipes(data.recipes, data.pagination, false)
    } catch (error) {
      console.error('Error loading more recipes:', error)
      this.currentPage-- // Revert page increment on error
    } finally {
      this.isLoading = false
    }
  }

  async fetchRecipes(ingredients, page) {
    const params = new URLSearchParams()
    ingredients.forEach(id => params.append('ingredient_ids[]', id))
    params.append('page', page)

    return fetch(`/recipes/match_ingredients?${params}`)
  }

  resetPagination() {
    this.currentPage = 1
    this.totalPages = 1
    this.totalCount = 0
    this.isLoading = false
    this.allRecipes = []
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

  displayRecipes(recipes, pagination, isNewSearch = true) {
    if (recipes.length === 0 && isNewSearch) {
      this.recipesSection.style.display = 'none'
      return
    }

    // Update pagination state
    this.currentPage = pagination.current_page
    this.totalPages = pagination.total_pages
    this.totalCount = pagination.total_count

    // Show the recipes section
    this.recipesSection.style.display = 'block'

    if (isNewSearch) {
      // Reset recipes for new search
      this.allRecipes = recipes
      this.renderRecipes()
    } else {
      // Append new recipes for infinite scroll
      this.allRecipes = [...this.allRecipes, ...recipes]
      this.appendRecipes(recipes)
    }

    // Setup infinite scroll observer if there are more pages
    if (pagination.has_next_page) {
      this.setupInfiniteScrollTrigger()
    } else {
      this.removeInfiniteScrollTrigger()
    }
  }

  renderRecipes() {
    const recipesHTML = this.buildRecipesHTML(this.allRecipes, this.totalCount)
    this.recipesSection.innerHTML = recipesHTML
  }

  appendRecipes(newRecipes) {
    const recipesList = this.recipesSection.querySelector('ul')
    if (recipesList) {
      const newRecipesHTML = newRecipes.map(recipe => this.buildRecipeHTML(recipe)).join('')
      recipesList.insertAdjacentHTML('beforeend', newRecipesHTML)
    }
  }

  buildRecipesHTML(recipes, totalCount) {
    const header = `<h3 class="text-lg font-semibold mb-2">${totalCount} Recipe${totalCount === 1 ? '' : 's'} Found:</h3>`
    const recipesList = `<ul class="space-y-2">${recipes.map(recipe => this.buildRecipeHTML(recipe)).join('')}</ul>`
    const loadMoreTrigger = this.currentPage < this.totalPages ? '<div id="load-more-trigger" class="h-10"></div>' : ''

    return header + recipesList + loadMoreTrigger
  }

  buildRecipeHTML(recipe) {
    // Create ingredient count badges
    const totalBadge = `<span class="inline-block bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded-full mr-2">${recipe.total_ingredients_count} total ingredients</span>`

    let matchedBadge, missingBadge

    if (recipe.missing_ingredients_count === 0) {
      // All ingredients are available - show "All at home" in green
      matchedBadge = `<span class="inline-block bg-green-100 text-green-800 text-xs px-2 py-1 rounded-full mr-2">✓ All at home</span>`
      missingBadge = '' // Don't show missing badge when there are no missing ingredients
    } else {
      // Some ingredients are missing - show "X at home" in yellow and missing count
      matchedBadge = `<span class="inline-block bg-yellow-100 text-yellow-800 text-xs px-2 py-1 rounded-full mr-2">✓ ${recipe.matched_ingredients_count} at home</span>`
      missingBadge = `<span class="inline-block bg-red-100 text-red-800 text-xs px-2 py-1 rounded-full">⚠ ${recipe.missing_ingredients_count} missing</span>`
    }

    // Get the list of selected ingredients for interactive buttons
    const selectedIngredients = Array.from(this.ingredientsList.querySelectorAll('[data-ingredient-id]'))
      .map(el => ({
        id: el.dataset.ingredientId,
        name: el.dataset.ingredientName
      }))

    // Create interactive ingredient buttons
    const ingredientButtons = recipe.ingredients.map(ingredient => {
      const selectedIngredient = selectedIngredients.find(sel =>
        sel.name.toLowerCase() === ingredient.toLowerCase()
      )

      if (selectedIngredient) {
        // Ingredient is available - show green button with remove action
        return `
          <button
            class="inline-flex items-center gap-1 px-3 py-1 bg-green-100 text-green-800 rounded-full text-sm hover:bg-green-200 transition-colors"
            data-action="click->ingredient-search#removeIngredientFromRecipe"
            data-ingredient-id="${selectedIngredient.id}"
            data-ingredient-name="${selectedIngredient.name}"
            title="Remove ${ingredient} from selected ingredients"
          >
            <span>${ingredient}</span>
            <span class="ml-1 text-green-600 hover:text-green-800">×</span>
          </button>
        `
      } else {
        // Ingredient is missing - show red button with add action
        return `
          <button
            class="inline-flex items-center gap-1 px-3 py-1 bg-red-100 text-red-800 rounded-full text-sm hover:bg-red-200 transition-colors"
            data-action="click->ingredient-search#addIngredientFromRecipe"
            data-ingredient-name="${ingredient}"
            title="Add ${ingredient} to selected ingredients"
          >
            <span>${ingredient}</span>
            <span class="ml-1 text-red-600 hover:text-red-800">+</span>
          </button>
        `
      }
    }).join('')

    return `
      <li class="p-4 bg-gray-50 rounded-lg border">
        <div class="flex justify-between items-start mb-2">
          <h4 class="font-semibold text-lg">${recipe.name}</h4>
          <div class="flex flex-wrap gap-1">
            ${totalBadge}
            ${matchedBadge}
            ${missingBadge}
          </div>
        </div>
        <div class="text-sm text-gray-600">
          <span class="block mb-2">Ingredients:</span>
          <div class="flex flex-wrap gap-2">
            ${ingredientButtons}
          </div>
        </div>
      </li>
    `
  }

  setupInfiniteScrollTrigger() {
    this.removeInfiniteScrollTrigger()

    const trigger = document.getElementById('load-more-trigger')
    if (trigger) {
      this.observer.observe(trigger)
    }
  }

  removeInfiniteScrollTrigger() {
    const trigger = document.getElementById('load-more-trigger')
    if (trigger) {
      this.observer.unobserve(trigger)
    }
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

  disconnect() {
    // Clean up the intersection observer
    if (this.observer) {
      this.observer.disconnect()
    }
  }
}

