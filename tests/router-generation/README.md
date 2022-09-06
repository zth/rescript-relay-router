# Test - Router Generation

This test case ensures that the R3 CLI outputs ReScript code that is accepted by the ReScript compiler based on a test `routes.json` file.

## Reading test failures

In case ReScript fails to build it will provide an error for a specific filename. The filename can be used to deduce the specific test case in `routes.json` that failed.
