---
"rescript-relay-router": patch
---

Support running route loaders on change of query parameters as well, not just on path changes. Introduce shallow routing mode to preserve previous behavior of `setParams` not triggering route data loaders.
