---
"rescript-relay-router": patch
---

Centralize router location subscriptions so location-consuming hooks share the router's history listener and still update during shallow navigations.
