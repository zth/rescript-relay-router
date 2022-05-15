module.exports = {
  stories: ["../src/**/*.stories.mdx", "../src/**/*Stories.bs.js"],
  addons: [
    {
      name: "@storybook/addon-essentials",
      options: {
        controls: false,
      },
    },
    "@storybook/addon-links",
    "@storybook/addon-knobs",
    {
      name: "@storybook/addon-postcss",
      options: {
        postcssLoaderOptions: {
          implementation: require("postcss"),
        },
      },
    },
  ],
};
