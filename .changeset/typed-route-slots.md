---
"rescript-relay-router": minor
---

Add typed route slots for rendering descendant route branches into named parent outlets.

Routes can now declare `slots`, descendant routes can target an ancestor slot with `outlet`, and generated route modules expose typed slot components such as `Routes.Root.Slots.Overlay`.
