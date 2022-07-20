# Tests

Packages in this folder are not intended to be full fledged examples but instead serve as bare bones regression and integration tests.

**Test cases MUST NOT include a `build` script to ensure that tooling can be rebuild in the repository even if tests are failing**
**Test cases MUST include a `test` script that returns a non-zero status code on test failure**
