module.exports = [
  // Add support for native node modules
  {
    test: /\.node$/,
    use: 'node-loader',
  },
  {
    test: /\.(m?js|node)$/,
    parser: { amd: false },
    use: {
      loader: '@marshallofsound/webpack-asset-relocator-loader',
      options: {
        outputAssetBase: 'native_modules',
      },
    },
  },
  {
    test: /\.tsx?$/,
    exclude: /(node_modules|\.webpack)/,
    use: {
      loader: 'babel-loader',
      options: {
        // transpileOnly: true,
        presets: ['@babel/preset-react', '@babel/typescript'],
      }
    }
  },
  {
    resolve: {
      alias: { 'react-dom': '@hot-loader/react-dom'  }
    }
  }
];
