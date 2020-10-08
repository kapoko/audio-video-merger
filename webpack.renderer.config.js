const rules = require('./webpack.rules');
const plugins = require('./webpack.plugins');

rules.push({
  test: /\.s[ac]ss$/i,
  use: [
    // Creates `style` nodes from JS strings
    'style-loader',
    // Translates CSS into CommonJS
    'css-loader',
    // Compiles Sass to CSS
    'sass-loader',
  ],
});

module.exports = {
  module: {
    rules,
  },
  plugins: plugins,
  resolve: {
    extensions: ['.js', '.ts', '.jsx', '.tsx', '.css']
  },
};
