const rules = require('./webpack.rules');
const ForkTsCheckerWebpackPlugin = require('fork-ts-checker-webpack-plugin');
const StylelintPlugin = require('stylelint-webpack-plugin');

rules.push({
  test: /\.s[ac]ss$/i,
  use: [
    'style-loader',
    'css-loader',
    'sass-loader',
  ],
});

module.exports = {
  module: {
    rules,
  },
  target: 'electron-renderer',
  plugins: [
    new ForkTsCheckerWebpackPlugin(),
    new StylelintPlugin({
      fix: true
    }),
  ],
  resolve: {
    extensions: ['.js', '.ts', '.jsx', '.tsx', '.css']
  },
};
