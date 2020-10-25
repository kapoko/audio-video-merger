const isDev = process.env.NODE_ENV === 'development'

const path = require("path");
const AssetsPlugin = require("assets-webpack-plugin");
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const { CleanWebpackPlugin } = require('clean-webpack-plugin');
const StylelintPlugin = require('stylelint-webpack-plugin');

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
        new MiniCssExtractPlugin({
            filename: '[name].[contenthash:8].css'
        }),
        new StylelintPlugin({
            fix: true
        }),
    ]
}
  