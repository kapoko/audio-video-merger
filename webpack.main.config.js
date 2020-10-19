const webpack = require('webpack');
const CopyPlugin = require('copy-webpack-plugin');
const PermissionsOutputPlugin = require('webpack-permissions-plugin');
const path = require('path');
const ESLintPlugin = require('eslint-webpack-plugin');

module.exports = {
  /**
   * This is the main entry point for your application, it's the first file
   * that runs in the main process.
   */
  entry: './src/index.ts',
  target: 'electron-main',
  // Put your normal webpack config below here
  module: {
    rules: require('./webpack.rules'),
  },
  resolve: {
    extensions: ['.js', '.ts', '.jsx', '.tsx', '.css', '.json']
  },
  plugins: [
    new webpack.DefinePlugin({
      'process.env.FLUENTFFMPEG_COV': false
    }),
    new CopyPlugin({
      patterns: [
        'node_modules/ffmpeg-static/ffmpeg'
      ],
    }),
    new PermissionsOutputPlugin({
      buildFiles: [
        {
          path: path.resolve(__dirname, '.webpack', 'main', 'ffmpeg'),
          fileMode: '755'
        },
      ]
    }),
    /**
     * ESLintPlugin is only run inside main config, but applies to all 
     * files for renderer as well
     */
    new ESLintPlugin({
      context: 'src/',
      extensions: ['ts', 'tsx'],
      fix: true
    }),
  ]
}