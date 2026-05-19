---
"rescript-relay-router": major
---

Migrate the package to ReScript 12/Rewatch and remove the unused SSR streaming stack.

Projects must use ReScript 12, regenerate router output, and no longer import the removed `./server` package export or SSR streaming helpers. Removed APIs include the server Vite plugin, manifest transform, `RelayRouter.Manifest`, `RelayRouter.PreloadInsertingStream`, and the SSR preload insertion utilities.
