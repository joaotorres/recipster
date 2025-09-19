require 'rails_helper'

RSpec.describe ImportRecipes, '.clean_ingredient_name' do
  describe '.clean_ingredient_name' do
    it 'removes fractions and measurements correctly' do
      expect(ImportRecipes.send(:clean_ingredient_name, '1 cup all-purpose flour')).to eq('all-purpose flour')
      expect(ImportRecipes.send(:clean_ingredient_name, '⅔ cup white sugar')).to eq('white sugar')
      expect(ImportRecipes.send(:clean_ingredient_name, '1 teaspoon salt')).to eq('salt')
      expect(ImportRecipes.send(:clean_ingredient_name, '3 ½ teaspoons baking powder')).to eq('baking powder')
    end

    it 'removes descriptive words' do
      expect(ImportRecipes.send(:clean_ingredient_name, '1 cup chopped fresh cilantro')).to eq('cilantro')
      expect(ImportRecipes.send(:clean_ingredient_name, '2 tablespoons olive oil, divided')).to eq('olive oil')
      expect(ImportRecipes.send(:clean_ingredient_name, '1 (15 ounce) can chickpeas, drained and rinsed')).to eq('chickpea')
    end

    it 'handles edge cases' do
      expect(ImportRecipes.send(:clean_ingredient_name, '1 egg')).to eq('egg')
      expect(ImportRecipes.send(:clean_ingredient_name, '1 cup milk')).to eq('milk')
      expect(ImportRecipes.send(:clean_ingredient_name, '⅓ cup vegetable oil')).to eq('vegetable oil')
    end

    it 'returns nil for invalid inputs' do
      expect(ImportRecipes.send(:clean_ingredient_name, '')).to be_nil
      expect(ImportRecipes.send(:clean_ingredient_name, nil)).to be_nil
      expect(ImportRecipes.send(:clean_ingredient_name, '2g')).to be_nil
      expect(ImportRecipes.send(:clean_ingredient_name, '1cl')).to be_nil
    end

    it 'handles complex measurements' do
      expect(ImportRecipes.send(:clean_ingredient_name, '3 (12 ounce) packages refrigerated biscuit dough')).to eq('biscuit dough')
      expect(ImportRecipes.send(:clean_ingredient_name, '1 ½ cups whole wheat flour')).to eq('wheat flour')
      expect(ImportRecipes.send(:clean_ingredient_name, '4 ½ teaspoons baking powder')).to eq('baking powder')
    end

    it 'removes leading commas from descriptive words' do
      expect(ImportRecipes.send(:clean_ingredient_name, '1 onion, chopped')).to eq('onion')
      expect(ImportRecipes.send(:clean_ingredient_name, '2 cloves garlic, minced')).to eq('garlic')
      expect(ImportRecipes.send(:clean_ingredient_name, '1 bell pepper, diced')).to eq('bell pepper')
      expect(ImportRecipes.send(:clean_ingredient_name, '1 cup cheese, grated')).to eq('cheese')
    end

    it 'handles typical comma-separated descriptive words' do
      expect(ImportRecipes.send(:clean_ingredient_name, '1 (16 ounce) package kielbasa sausage, cut into 1/4-inch slices')).to eq('kielbasa sausage')
      expect(ImportRecipes.send(:clean_ingredient_name, '4 small zucchini, cut into 1/4-inch slices')).to eq('zucchini')
      expect(ImportRecipes.send(:clean_ingredient_name, '1 (6 ounce) package baby portobello mushrooms, sliced')).to eq('baby portobello mushroom')
      expect(ImportRecipes.send(:clean_ingredient_name, '1 red bell pepper, cut into strips')).to eq('red bell pepper')
      expect(ImportRecipes.send(:clean_ingredient_name, '3 cloves garlic, minced')).to eq('garlic')
      expect(ImportRecipes.send(:clean_ingredient_name, '¼ cup grated Parmesan cheese')).to eq('parmesan cheese')
    end

    it 'handles space-separated descriptive words' do
      expect(ImportRecipes.send(:clean_ingredient_name, '¼ cup chopped onion')).to eq('onion')
      expect(ImportRecipes.send(:clean_ingredient_name, '2 tablespoons butter')).to eq('butter')
      expect(ImportRecipes.send(:clean_ingredient_name, '2 large baking potatoes')).to eq('baking potato')
    end

    it 'removes can and package units correctly' do
      expect(ImportRecipes.send(:clean_ingredient_name, '1 (15 ounce) can diced tomatoes')).to eq('tomato')
      expect(ImportRecipes.send(:clean_ingredient_name, '1 (8 ounce) can tomato sauce')).to eq('tomato sauce')
      expect(ImportRecipes.send(:clean_ingredient_name, '1 (6 ounce) can tomato paste')).to eq('tomato paste')
      expect(ImportRecipes.send(:clean_ingredient_name, '1 (16 ounce) package kielbasa sausage')).to eq('kielbasa sausage')
      expect(ImportRecipes.send(:clean_ingredient_name, '1 (16 ounce) package farfalle pasta')).to eq('farfalle pastum')
      expect(ImportRecipes.send(:clean_ingredient_name, '1 (6 ounce) package baby portobello mushrooms')).to eq('baby portobello mushroom')
      expect(ImportRecipes.send(:clean_ingredient_name, 'can diced tomatoes')).to eq('tomato')
      expect(ImportRecipes.send(:clean_ingredient_name, 'package kielbasa sausage')).to eq('kielbasa sausage')
      expect(ImportRecipes.send(:clean_ingredient_name, '1 can diced tomatoes')).to eq('tomato')
      expect(ImportRecipes.send(:clean_ingredient_name, '1 package kielbasa sausage')).to eq('kielbasa sausage')
    end

    it 'removes everything after comma correctly' do
      expect(ImportRecipes.send(:clean_ingredient_name, '2 eggs, beaten')).to eq('egg')
      expect(ImportRecipes.send(:clean_ingredient_name, '¼ cup butter, cubed')).to eq('butter')
      expect(ImportRecipes.send(:clean_ingredient_name, '3 large bananas, mashed')).to eq('banana')
      expect(ImportRecipes.send(:clean_ingredient_name, '⅓ cup butter, melted')).to eq('butter')
      expect(ImportRecipes.send(:clean_ingredient_name, '1 teaspoon ground cinnamon, or to taste')).to eq('ground cinnamon')
      expect(ImportRecipes.send(:clean_ingredient_name, '¼ cup vegetable oil, or as needed')).to eq('vegetable oil')
      expect(ImportRecipes.send(:clean_ingredient_name, '3 cups bread flour, divided, or as needed')).to eq('bread flour')
      expect(ImportRecipes.send(:clean_ingredient_name, '1 Granny Smith apple - peeled, cored and coarsely shredded')).to eq('granny smith apple -')
      expect(ImportRecipes.send(:clean_ingredient_name, '7 tablespoons unsalted butter, chilled in freezer and cut into thin slices')).to eq('unsalted butter')
      expect(ImportRecipes.send(:clean_ingredient_name, '1 (15 ounce) can diced tomatoes, drained and rinsed')).to eq('tomato')
    end
  end
end
