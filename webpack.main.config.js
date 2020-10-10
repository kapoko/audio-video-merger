const webpack = require('webpack');
const CopyPlugin = require('copy-webpack-plugin');
const PermissionsOutputPlugin = require('webpack-permissions-plugin');
const path = require('path');

module.exports = //[
  {
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
          { from: 'node_modules/ffmpeg-static/ffmpeg', to: '.' },
        ],
      }),
      new PermissionsOutputPlugin({
        buildFiles: [
          {
            path: path.resolve(__dirname, '.webpack', 'main', 'ffmpeg'),
            fileMode: '755'
          },
        ]
      })
    ]
  }
  // {
  //   entry: './src/preload.ts',
  //   target: 'electron-preload',
  //   output: {
  //     path: path.join(__dirname, 'dist'),
  //     filename: 'preload.bundled.js'
  //   },
  //   module: {
  //     rules: require('./webpack.rules'),
  //   }
  // },
//];
