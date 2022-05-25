# Contributing

Thank you for taking the time to contribute to ReScript Relay Router!

## Getting started

This repository uses [yarn 1](https://classic.yarnpkg.com/en/docs/install) as a package manager.

### Issues

#### Create a new issue

If you spot a problem with the docs, [search if an issue already exists](https://docs.github.com/en/github/searching-for-information-on-github/searching-on-github/searching-issues-and-pull-requests#search-by-the-title-body-or-comments). If a related issue doesn't exist, you can open a new issue using a relevant [issue form](https://github.com/zth/rescript-relay-router/issues/new/choose).

#### Solve an issue

Scan through our [existing issues](https://github.com/zth/rescript-relay-router/issues) to find one that interests you. You can narrow down the search using `labels` as filters.

### Make changes

1. Fork the repository.
- Using GitHub Desktop:
  - [Getting started with GitHub Desktop](https://docs.github.com/en/desktop/installing-and-configuring-github-desktop/getting-started-with-github-desktop) will guide you through setting up Desktop.
  - Once Desktop is set up, you can use it to [fork the repo](https://docs.github.com/en/desktop/contributing-and-collaborating-using-github-desktop/cloning-and-forking-repositories-from-github-desktop)!

- Using the command line:
  - [Fork the repo](https://docs.github.com/en/github/getting-started-with-github/fork-a-repo#fork-an-example-repository) so that you can make your changes without affecting the original project until you're ready to merge them.

3. Install or update to **Node.js v16** or newer. You must have [yarn 1 installed](https://classic.yarnpkg.com/en/docs/install).

4. Install the project's dependencies using `yarn`

5. Start the development server using `yarn dev`. This will start all the tools for you.

6. You can now view the site at `http://localhost:9999` and make changes.

When you're ready to stop your local server, type <kbd>Ctrl</kbd>+<kbd>C</kbd> in your terminal window.

To build the project in production mode run `yarn build`. You can preview the production build using `yarn serve`.

Once you're satisfied with the production build you can package a new version of the router for use in other projects by running `./buildPackage.sh` which will copy the router files into the `_release/` folder.


