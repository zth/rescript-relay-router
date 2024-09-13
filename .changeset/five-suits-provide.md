---
"rescript-relay-router": patch
---

Ensure query params are always fresh when updated. Removes stale closure problems, reduces generated code size, and make query param setter fns stable.
