const neostandard = require('neostandard')
const pluginVue = require('eslint-plugin-vue')

// Successor to eslint-config-standard (flat config). Style rules come from
// @stylistic via neostandard; Vue 3 rules from eslint-plugin-vue.
module.exports = [
  ...neostandard({
    env: ['browser'],
    ignores: ['node_modules/**', 'public/**', 'tmp/**', 'vendor/**', 'coverage/**']
  }),
  ...pluginVue.configs['flat/recommended'],
  {
    files: ['**/*.vue'],
    languageOptions: {
      parserOptions: {
        parser: '@babel/eslint-parser',
        ecmaVersion: 2022,
        sourceType: 'module'
      }
    }
  },
  {
    rules: {
      'vue/no-deprecated-html-element-is': 'off',
      'vue/no-mutating-props': 'off',
      'vue/one-component-per-file': 'off'
    }
  }
]
