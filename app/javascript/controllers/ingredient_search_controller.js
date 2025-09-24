import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.setupAutocomplete()
    this.setupEventListeners()
    this.setupInfiniteScroll()
    this.setupFilterForm()

    // Initialize pagination state
    this.currentPage = 1
    this.totalPages = 1
    this.totalCount = 0
    this.isLoading = false
    this.allRecipes = []

    // Load top recipes on page load
    this.loadTopRecipes()
  }

  setupAutocomplete() {
    this.input = this.element.querySelector('input[type="search"]')
    this.ingredientsList = document.getElementById('ingredients-list')
    this.recipesSection = document.getElementById('recipes-section')
    this.messagesDiv = document.getElementById('messages')

    // Initialize keyboard navigation state
    this.selectedIndex = -1

    // Simple debounced search
    this.searchTimeout = null
    this.input.addEventListener('input', (e) => {
      clearTimeout(this.searchTimeout)
      this.searchTimeout = setTimeout(() => {
        this.searchIngredients(e.target.value)
      }, 300)
    })

    // Handle keyboard navigation
    this.input.addEventListener('keydown', (e) => {
      const dropdown = document.querySelector('.suggestions-dropdown')
      const items = dropdown ? dropdown.querySelectorAll('.suggestion-item') : []

      switch (e.key) {
        case 'ArrowDown':
          e.preventDefault()
          if (items.length > 0) {
            this.selectedIndex = Math.min(this.selectedIndex + 1, items.length - 1)
            this.highlightItem(items)
          }
          break
        case 'ArrowUp':
          e.preventDefault()
          if (items.length > 0) {
            this.selectedIndex = Math.max(this.selectedIndex - 1, -1)
            this.highlightItem(items)
          }
          break
        case 'Enter':
          e.preventDefault()
          const inputValue = this.input.value.trim()

          if (this.selectedIndex >= 0 && this.selectedIndex < items.length) {
            // User has selected an item with keyboard navigation
            items[this.selectedIndex].click()
          } else if (inputValue) {
            // Check if the input text exactly matches any of the current suggestions
            const exactMatch = Array.from(items).find(item =>
              item.textContent.toLowerCase() === inputValue.toLowerCase()
            )

            if (exactMatch) {
              // Found exact match - add the ingredient
              exactMatch.click()
            } else {
              // No exact match found - perform a search to check if ingredient exists
              this.handleEnterWithNoSelection(inputValue)
            }
          }
          break
        case 'Escape':
          this.hideSuggestions()
          this.input.blur()
          break
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

    // Common ingredient buttons
    document.querySelectorAll('.common-ingredient-btn').forEach(button => {
      button.addEventListener('click', (e) => {
        const ingredientName = e.currentTarget.dataset.ingredientName
        this.addCommonIngredient(ingredientName)
      })
    })
  }

  setupFilterForm() {
    // Apply filters button
    const applyFiltersBtn = document.getElementById('apply-filters')
    if (applyFiltersBtn) {
      applyFiltersBtn.addEventListener('click', () => {
        this.applyFilters()
      })
    }

    // Auto-apply filters when radio buttons change
    const radioButtons = document.querySelectorAll('input[type="radio"]')
    radioButtons.forEach(radio => {
      radio.addEventListener('change', () => {
        this.applyFilters()
      })
    })

    // Auto-apply filters when select changes
    const selectElement = document.querySelector('select')
    if (selectElement) {
      selectElement.addEventListener('change', () => {
        this.applyFilters()
      })
    }

    // Setup recipe search form
    this.setupRecipeSearchForm()
  }

  setupRecipeSearchForm() {
    const searchForm = document.getElementById('recipe-search-form')
    const searchInput = document.getElementById('recipe-name-search')

    if (searchForm && searchInput) {
      // Handle form submission
      searchForm.addEventListener('submit', (e) => {
        e.preventDefault()
        this.applyFilters()
      })

      // Auto-search as user types (with debounce)
      let searchTimeout = null
      searchInput.addEventListener('input', () => {
        clearTimeout(searchTimeout)
        searchTimeout = setTimeout(() => {
          this.applyFilters()
        }, 500) // 500ms debounce
      })
    }
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
    // Only clear error messages when user is actively typing (not when input is cleared programmatically)
    if (query.length > 0) {
      this.clearIngredientErrorMessage()
    }

    if (query.length < 1) {
      this.hideSuggestions()
      return
    }

    try {
      const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`)
      const ingredients = await response.json()
      this.showSuggestions(ingredients)

      // Auto-highlight first item if suggestions are shown
      if (ingredients.length > 0) {
        this.selectedIndex = 0
        const dropdown = document.querySelector('.suggestions-dropdown')
        if (dropdown) {
          const items = dropdown.querySelectorAll('.suggestion-item')
          this.highlightItem(items)
        }
      }
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

    // Reset selected index when showing new suggestions
    this.selectedIndex = -1

    // Create suggestions dropdown
    const dropdown = document.createElement('div')
    dropdown.className = 'suggestions-dropdown w-full bg-white border border-gray-300 rounded-lg shadow-lg max-h-60 overflow-y-auto'

    ingredients.forEach((ingredient, index) => {
      const item = document.createElement('div')
      item.className = 'suggestion-item px-4 py-2 hover:bg-gray-100 cursor-pointer border-b border-gray-100 last:border-b-0'
      item.textContent = ingredient.name
      item.dataset.ingredientId = ingredient.id
      item.dataset.ingredientName = ingredient.name

      item.addEventListener('click', () => {
        this.addIngredient(ingredient.id, ingredient.name)
        this.input.value = ''
        dropdown.remove()
      })

      // Add mouse hover effects
      item.addEventListener('mouseenter', () => {
        this.selectedIndex = index
        this.highlightItem(dropdown.querySelectorAll('.suggestion-item'))
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
    this.selectedIndex = -1
  }

  highlightItem(items) {
    items.forEach((item, index) => {
      if (index === this.selectedIndex) {
        item.classList.add('bg-blue-100', 'text-blue-800')
        item.classList.remove('hover:bg-gray-100')
      } else {
        item.classList.remove('bg-blue-100', 'text-blue-800')
        item.classList.add('hover:bg-gray-100')
      }
    })
  }

  async handleEnterWithNoSelection(inputValue) {
    try {
      // Perform a search to check if the ingredient exists
      const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(inputValue)}`)
      const ingredients = await response.json()

      // Look for an exact match (case-insensitive)
      const exactMatch = ingredients.find(ingredient =>
        ingredient.name.toLowerCase() === inputValue.toLowerCase()
      )

      if (exactMatch) {
        // Found exact match - add the ingredient
        this.addIngredient(exactMatch.id, exactMatch.name)
        this.input.value = ''
        this.hideSuggestions()
      } else {
        // No exact match found - show error message
        this.handleIngredientNotFound(inputValue)
      }
    } catch (error) {
      console.error('Error checking ingredient:', error)
      this.handleIngredientNotFound(inputValue)
    }
  }

  handleIngredientNotFound(inputValue) {
    // Hide any existing suggestions
    this.hideSuggestions()

    // Show not found message under the ingredient input field
    this.showIngredientErrorMessage(`"${inputValue}" not found`)

    // Clear the input field after showing the message
    this.input.value = ''

    // Clear the message after 3 seconds
    setTimeout(() => {
      this.clearIngredientErrorMessage()
    }, 3000)
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
    this.clearIngredientErrorMessage() // Clear any ingredient-specific error messages

    // Hide the corresponding common ingredient button
    this.hideCommonIngredient(name)

    // Automatically search for recipes when ingredient is added
    this.searchRecipes()
  }

  async addCommonIngredient(ingredientName) {
    try {
      // Search for the ingredient to get its ID
      const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(ingredientName)}`)
      const ingredients = await response.json()

      // Look for an exact match (case-insensitive)
      const exactMatch = ingredients.find(ingredient =>
        ingredient.name.toLowerCase() === ingredientName.toLowerCase()
      )

      if (exactMatch) {
        // Found exact match - add the ingredient
        this.addIngredient(exactMatch.id, exactMatch.name)
      } else {
        // Show error message if ingredient not found
        this.showIngredientErrorMessage(`"${ingredientName}" not found in database`)
        setTimeout(() => {
          this.clearIngredientErrorMessage()
        }, 3000)
      }
    } catch (error) {
      console.error('Error adding common ingredient:', error)
      this.showIngredientErrorMessage(`Error adding "${ingredientName}"`)
      setTimeout(() => {
        this.clearIngredientErrorMessage()
      }, 3000)
    }
  }

  removeIngredient(event) {
    const ingredientElement = event.target.closest('[data-ingredient-id]')
    const ingredientName = ingredientElement.dataset.ingredientName

    ingredientElement.remove()

    // Show the corresponding common ingredient button again
    this.showCommonIngredient(ingredientName)

    // Automatically search for recipes when ingredient is removed
    this.searchRecipes()
  }

  removeIngredientFromRecipe(event) {
    const ingredientElement = event.target.closest('[data-ingredient-id]')
    const ingredientId = ingredientElement.dataset.ingredientId
    const ingredientName = ingredientElement.dataset.ingredientName
    const selectedIngredientElement = this.ingredientsList.querySelector(`[data-ingredient-id="${ingredientId}"]`)

    if (selectedIngredientElement) {
      selectedIngredientElement.remove()

      // Show the corresponding common ingredient button again
      this.showCommonIngredient(ingredientName)

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

    // Show all common ingredient buttons again
    document.querySelectorAll('.common-ingredient-btn').forEach(button => {
      button.style.display = 'inline-flex'
    })

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
    // When ingredients are added/removed, apply all current filters
    this.applyFilters()
  }

  async loadMoreRecipes() {
    if (this.isLoading || this.currentPage >= this.totalPages) return

    this.isLoading = true
    this.currentPage++

    const ingredients = Array.from(this.ingredientsList.querySelectorAll('[data-ingredient-id]'))
      .map(el => el.dataset.ingredientId)

    const filters = this.getFilterValues()

    try {
      const params = new URLSearchParams()

      // Add ingredient IDs
      ingredients.forEach(id => params.append('ingredient_ids[]', id))

      // Add filter values
      if (filters.name) params.append('name', filters.name)
      if (filters.max_time) params.append('max_time', filters.max_time)
      if (filters.min_rating) params.append('min_rating', filters.min_rating)
      if (filters.category) params.append('category', filters.category)

      params.append('page', this.currentPage)

      const response = await fetch(`/recipes/search?${params.toString()}`)
      const data = await response.json()

      this.displayRecipes(data.recipes, data.pagination, false)
    } catch (error) {
      console.error('Error loading more recipes:', error)
      this.currentPage-- // Revert page increment on error
    } finally {
      this.isLoading = false
    }
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
    // Check if we have any search criteria
    const hasSearchCriteria = this.hasSearchCriteria()

    let header
    if (hasSearchCriteria) {
      header = `<h3 class="text-lg font-semibold mb-2">${totalCount} Recipe${totalCount === 1 ? '' : 's'} Found:</h3>`
    } else {
      header = `<h3 class="text-lg font-semibold mb-2">Top Recipes:</h3>`
    }

    const recipesList = `<ul class="space-y-2">${recipes.map(recipe => this.buildRecipeHTML(recipe)).join('')}</ul>`
    const loadMoreTrigger = this.currentPage < this.totalPages ? '<div id="load-more-trigger" class="h-10"></div>' : ''

    return header + recipesList + loadMoreTrigger
  }

  buildRecipeHTML(recipe) {
    // Create ingredient count badges
    const totalBadge = `<span class="inline-block bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded-full mr-2">${recipe.total_ingredients_count} total ingredients</span>`

    let matchedBadge, missingBadge

    // Check if ingredient matching data is available (when ingredients are selected)
    if (recipe.matched_ingredients_count !== null && recipe.missing_ingredients_count !== null) {
      if (recipe.missing_ingredients_count === 0) {
        // All ingredients are available - show "All at home" in green
        matchedBadge = `<span class="inline-block bg-green-100 text-green-800 text-xs px-2 py-1 rounded-full mr-2">✓ All at home</span>`
        missingBadge = '' // Don't show missing badge when there are no missing ingredients
      } else {
        // Some ingredients are missing - show "X at home" in yellow and missing count
        matchedBadge = `<span class="inline-block bg-yellow-100 text-yellow-800 text-xs px-2 py-1 rounded-full mr-2">✓ ${recipe.matched_ingredients_count} at home</span>`
        missingBadge = `<span class="inline-block bg-red-100 text-red-800 text-xs px-2 py-1 rounded-full">⚠ ${recipe.missing_ingredients_count} missing</span>`
      }
    } else {
      // No ingredients selected - show all ingredients as missing
      matchedBadge = ''
      missingBadge = `<span class="inline-block bg-red-100 text-red-800 text-xs px-2 py-1 rounded-full">⚠ ${recipe.total_ingredients_count} missing</span>`
    }

    // Calculate total cooking time
    const totalTime = (recipe.prep_time || 0) + (recipe.cook_time || 0)
    const timeDisplay = totalTime > 0 ? `${totalTime} min` : 'N/A'

    // Create star rating display
    const rating = parseFloat(recipe.rating) || 0
    const fullStars = Math.floor(rating)
    const hasHalfStar = rating % 1 >= 0.5
    const emptyStars = 5 - fullStars - (hasHalfStar ? 1 : 0)

    const starsHTML = '★'.repeat(fullStars) +
                     (hasHalfStar ? '☆' : '') +
                     '☆'.repeat(emptyStars)

    const ratingDisplay = `<div class="flex items-center gap-1 text-sm">
      <span class="text-yellow-500">${starsHTML}</span>
      <span class="text-gray-600">${rating.toFixed(1)}</span>
    </div>`

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

    // Create image element
    const imageHTML = recipe.image ?
      `<img src="${recipe.image}" alt="${recipe.name}" class="w-24 h-24 object-cover rounded-lg flex-shrink-0">` :
      `<div class="w-24 h-24 bg-gray-200 rounded-lg flex items-center justify-center text-gray-400 text-xs">No Image</div>`

    return `
      <li class="p-4 bg-gray-50 rounded-lg border">
        <div class="flex gap-4">
          <!-- Recipe Image -->
          <div class="flex-shrink-0">
            ${imageHTML}
          </div>

          <!-- Recipe Content -->
          <div class="flex-1 min-w-0">
            <!-- Recipe Name and Meta Info -->
            <div class="flex justify-between items-start mb-2">
              <h4 class="font-semibold text-lg">${recipe.name}</h4>
              <div class="flex items-center gap-4 text-sm text-gray-600">
                <div class="flex items-center gap-1">
                  <span>🕒</span>
                  <span>${timeDisplay}</span>
                </div>
                ${ratingDisplay}
              </div>
            </div>

            <!-- Ingredient Badges -->
            <div class="flex flex-wrap gap-1 mb-3">
              ${totalBadge}
              ${matchedBadge}
              ${missingBadge}
            </div>

            <!-- Ingredients List -->
            <div class="text-sm text-gray-600">
              <span class="block mb-2">Ingredients:</span>
              <div class="flex flex-wrap gap-2">
                ${ingredientButtons}
              </div>
            </div>
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

  showIngredientErrorMessage(message) {
    // Remove any existing error message
    this.clearIngredientErrorMessage()

    // Create error message element
    const errorDiv = document.createElement('div')
    errorDiv.className = 'ingredient-error-message mt-2 p-2 bg-red-100 text-red-800 text-sm rounded-lg border border-red-200'
    errorDiv.textContent = message

    // Insert the error message after the ingredient input field
    const inputContainer = this.input.parentNode
    inputContainer.appendChild(errorDiv)
  }

  clearIngredientErrorMessage() {
    const existingError = this.input.parentNode.querySelector('.ingredient-error-message')
    if (existingError) {
      existingError.remove()
    }
  }

  hideCommonIngredient(ingredientName) {
    const commonButton = document.querySelector(`[data-ingredient-name="${ingredientName}"]`)
    if (commonButton) {
      commonButton.style.display = 'none'
    }
  }

  showCommonIngredient(ingredientName) {
    const commonButton = document.querySelector(`[data-ingredient-name="${ingredientName}"]`)
    if (commonButton) {
      commonButton.style.display = 'inline-flex'
    }
  }

  getFilterValues() {
    const cookingTime = document.querySelector('input[name="cooking-time"]:checked')?.value || ''
    const rating = document.querySelector('input[name="rating"]:checked')?.value || ''
    const category = document.querySelector('select')?.value || ''
    const name = document.getElementById('recipe-name-search')?.value || ''

    return {
      name: name,
      max_time: cookingTime,
      min_rating: rating,
      category: category
    }
  }

  hasSearchCriteria() {
    const ingredients = Array.from(this.ingredientsList.querySelectorAll('[data-ingredient-id]'))
    const filters = this.getFilterValues()

    return ingredients.length > 0 || Object.values(filters).some(value => value !== '')
  }

  async loadTopRecipes() {
    // Reset pagination for initial load
    this.resetPagination()

    // Show loading spinner
    this.showLoading()

    try {
      // Fetch top recipes (no search criteria)
      const response = await fetch('/recipes/search?page=1')
      const data = await response.json()

      this.hideLoading()
      this.displayRecipes(data.recipes, data.pagination, true)

      console.log(`🔍 Top recipes loaded - Found ${data.pagination.total_count} recipe${data.pagination.total_count === 1 ? '' : 's'}`)
    } catch (error) {
      console.error('❌ Error loading top recipes:', error)
      this.hideLoading()
      this.showMessage('Error loading recipes. Please try again.', 'error')
    }
  }

  async applyFilters() {
    const ingredients = Array.from(this.ingredientsList.querySelectorAll('[data-ingredient-id]'))
      .map(el => el.dataset.ingredientId)

    const filters = this.getFilterValues()
    const hasFilters = Object.values(filters).some(value => value !== '') || ingredients.length > 0

    // Always show recipes - either filtered results or top recipes
    // No need to hide the section when no filters are applied

    // Reset pagination for new search
    this.resetPagination()

    // Start timing the search
    const searchStartTime = performance.now()

    // Show loading spinner
    this.showLoading()

    try {
      const params = new URLSearchParams()

      // Add ingredient IDs
      ingredients.forEach(id => params.append('ingredient_ids[]', id))

      // Add filter values
      if (filters.name) params.append('name', filters.name)
      if (filters.max_time) params.append('max_time', filters.max_time)
      if (filters.min_rating) params.append('min_rating', filters.min_rating)
      if (filters.category) params.append('category', filters.category)

      params.append('page', '1')

      const response = await fetch(`/recipes/search?${params.toString()}`)
      const data = await response.json()

      // Calculate search duration
      const searchEndTime = performance.now()
      const searchDuration = Math.round(searchEndTime - searchStartTime)

      this.hideLoading()
      this.displayRecipes(data.recipes, data.pagination, true)

      // Log search performance
      const filterText = hasFilters ? ' with filters' : ''
      console.log(`🔍 Recipe search${filterText} completed in ${searchDuration}ms - Found ${data.pagination.total_count} recipe${data.pagination.total_count === 1 ? '' : 's'}`)
    } catch (error) {
      // Calculate search duration even on error
      const searchEndTime = performance.now()
      const searchDuration = Math.round(searchEndTime - searchStartTime)

      console.error(`❌ Recipe search failed after ${searchDuration}ms:`, error)
      this.hideLoading()
      this.showMessage('Error searching for recipes. Please try again.', 'error')
    }
  }

  disconnect() {
    // Clean up the intersection observer
    if (this.observer) {
      this.observer.disconnect()
    }
  }
}

