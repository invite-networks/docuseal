const { generateWebpackConfig, merge } = require('shakapacker')
const BundleAnalyzerPlugin = require('webpack-bundle-analyzer').BundleAnalyzerPlugin
const { VueLoaderPlugin } = require('vue-loader')

const configs = generateWebpackConfig({
  resolve: {
    extensions: ['.css', '.scss', '.vue']
  },
  performance: {
    maxEntrypointSize: 0
  },
  optimization: {
    runtimeChunk: false,
    concatenateModules: !process.env.BUNDLE_ANALYZE,
    splitChunks: {
      chunks (chunk) {
        return chunk.name !== 'rollbar_client' && chunk.name !== 'dynamic-editor'
      },
      cacheGroups: {
        default: false,
        applicationVendors: {
          test: /\/node_modules\//,
          chunks: chunk => chunk.name === 'application'
        },
        drawVendors: {
          test: /\/node_modules\//,
          chunks: chunk => chunk.name === 'draw'
        },
        formVendors: {
          test: /\/node_modules\//,
          chunks: chunk => chunk.name === 'form'
        }
      }
    }
  },
  plugins: [
    process.env.BUNDLE_ANALYZE && new BundleAnalyzerPlugin(),
    new VueLoaderPlugin()
  ].filter(Boolean)
})

// Rule 2 is shakapacker's CSS rule; the shadow-DOM stylesheet is imported as a string instead.
configs.module.rules[2].exclude = /dynamic_styles\.css$/

configs.module = merge({
  rules: [
    {
      test: /dynamic_styles\.css$/,
      use: ['css-loader', 'postcss-loader']
    },
    {
      test: /\.vue$/,
      use: [{
        loader: 'vue-loader',
        options: {
          compilerOptions: {
            isCustomElement: tag => tag.includes('-')
          }
        }
      }]
    }
  ]
}, configs.module)

module.exports = configs
