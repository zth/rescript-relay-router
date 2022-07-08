#!/bin/bash
rm -rf _release;
mkdir -p _release/cli/lsp;
mkdir _release/src;

cp -fr cli/*.mjs _release/cli;
cp -fr cli/lsp/*.mjs _release/cli/lsp;
cp -fr router/*.res* _release/src;

# Prepend hashbang to CLI file
echo '#!/usr/bin/env node' > /tmp/RescriptRelayRouterCli.mjs
cat _release/cli/RescriptRelayRouterCli.mjs >> /tmp/RescriptRelayRouterCli.mjs
cp /tmp/RescriptRelayRouterCli.mjs _release/cli/RescriptRelayRouterCli.js
rm _release/cli/RescriptRelayRouterCli.mjs

cp RescriptRelayVitePlugin.mjs _release;
cp VirtualHtmlVitePlugin.mjs _release;

cp pkgPackage.json _release/package.json;
cp pkgBsconfig.json _release/bsconfig.json;

cp README.md _release/
