const isDev = process.env.NODE_ENV === 'development'

const path = require("path");
const glob = require('glob-all');
const AssetsPlugin = require("assets-webpack-plugin");
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const { CleanWebpackPlugin } = require('clean-webpack-plugin');
const StylelintPlugin = require('stylelint-webpack-plugin');
const CopyPlugin = require('copy-webpack-plugin');
const { PurgeCSSPlugin } = require("purgecss-webpack-plugin");

const purgeCSSPaths = glob.sync([
    `${path.join(__dirname, 'layouts')}/**/*`
], { mark: true }).filter(function(f) { return !/\/$/.test(f); });

module.exports = {
    mode: isDev ? 'development' : 'production',
    watch: isDev,
    entry: {
        main: path.join(__dirname, "assets", "js", "main.ts"),
    },
    output: {
        filename: '[name].[contenthash:8].js',
        path: path.join(__dirname, 'dist')
    },
    resolve: {
        extensions: ['.ts', '.tsx', '.js']
    },
    optimization: isDev ? {} : {
        splitChunks: {
            cacheGroups: {
                styles: {
                    name: 'styles',
                    test: /\.css$/,
                    chunks: 'all',
                    enforce: true
                }
            }
        }
    },
    module: {
        rules: [
            {
                test: /\.tsx?$/,
                use: 'ts-loader',
                exclude: /node_modules/,
            },
            {
                test: /\.(sa|sc|c)ss$/,
                exclude: /node_modules/,
                use: [
                    isDev ? 'style-loader' : MiniCssExtractPlugin.loader, 
                    "css-loader", 
                    { 
                        loader: 'postcss-loader',
                        options: {
                            postcssOptions: {
                                plugins: [
                                    [
                                        'postcss-preset-env',
                                        {
                                            // Options
                                        },
                                    ],
                                ],
                            },
                        },
                    },
                    "sass-loader"
                ]
            }
        ],
    },
    plugins: [
        new CleanWebpackPlugin(),
        new AssetsPlugin({
            filename: "manifest.json",
            path: path.join(__dirname, "data"),
            prettyPrint: true,
            removeFullPathAutoPrefix: true
        }),
        new CopyPlugin({
            patterns: [
              {
                from: '../package.json',
                to: '../data/packageCopy.json'
              }
            ],
        }),
        new MiniCssExtractPlugin({
            filename: '[name].[contenthash:8].css'
        }),
        new PurgeCSSPlugin({
            paths: purgeCSSPaths
        }),
        new StylelintPlugin({
            fix: true
        }),
    ]
}
  
