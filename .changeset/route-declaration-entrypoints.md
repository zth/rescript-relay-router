---
"rescript-relay-router": minor
---

Add route declaration entrypoints for top-level route trees.

Top-level routes can now set `entrypoint: true` in route config, which generates a standalone `RouteDeclarations.<RouteName>.make()` module for building a router from only that route tree.
