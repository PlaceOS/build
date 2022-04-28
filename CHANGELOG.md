## Unreleased

## v0.13.0 (2022-04-27)

### Feat

- **logging**: configure OpenTelemetry

## v0.12.0 (2022-04-26)

### Feat

- **logging**: add configuration by LOG_LEVEL env var

## v0.11.1 (2022-03-15)

### Fix

- **drivers**: discovery matches abstract classes ([#39](https://github.com/PlaceOS/build/pull/39))

## v0.11.0 (2022-02-24)

### Refactor

- use central build image ([#38](https://github.com/PlaceOS/build/pull/38))

### Feat

- compress drivers on upload ([#37](https://github.com/PlaceOS/build/pull/37))

### Fix

- build require based artefacts to bin/drivers of the working directory

## v0.10.0 (2021-09-21)

### Refactor

- remove padding from base64 strings

### Fix

- **s3/unsigned**: prevent writes on unsigned client
- **s3**: prevent double encoding
- **driver-store/s3**: make ELF header read-only
- **driver-store/s3**: ensure stored drivers are ELF
- **api**: add s3 backed store flow

## v0.9.1 (2021-09-16)

### Refactor

- **driver_store/s3**: simplify cache lookup

## v0.9.0 (2021-09-16)

### Refactor

- **executable**: place commit before digest
- **digest**: reduce severity of logs

## v0.8.4 (2021-09-16)

### Fix

- **driver_store**: broken s3 lookup
- **drivers**: default `force_recompile` to false
- **drivers**: use short commit
- **drivers**: prioritise local commit in local_* methods
- prevent writes on unsigned client

### Feat

- **s3**: log query results

## v0.8.3 (2021-09-15)

### Fix

- **driver_store**: fetch driver from s3 store
- **driver_store/s3**: missing link operation
- **driver_store**: bugs with info retrieval

## v0.8.2 (2021-09-14)

### Fix

- **client**: extract `body_io` and fallback to `body`
- **client**: graceful handling of build failures
- **s3**: url form encode before writes

## v0.8.1 (2021-09-01)

### Fix

- ensure failed builds raise

## v0.8.0 (2021-08-31)

### Refactor

- **executable**: place digest first in filename

### Fix

- **s3**: encode key before write
- **cli:build**: abort if not entrypoints to build

### Feat

- **logging**: add sentry

## v0.7.0 (2021-08-26)

### Fix

- **executable**: construct glob correctly

## v0.6.0 (2021-08-26)

### Fix

- **drivers**: configure threads for require builds
- **api:driver**: correct path to binary
- **cli:build**: extract crystal version from constants
- **repository_store**: ignore requires outside repository
- **client**: return Array(commits), not Array(String)

### Refactor

- expand logging
- **constants**: use constants for store paths

### Feat

- **cli:build**: add `--discover` to auto-discover drivers

## v0.5.1 (2021-08-14)

### Fix

- **client**: add raise to compile method
- **drivers**: strip path in discovery
- defer API gen until types are known

### Refactor

- **digest**: lower verbosity on digest

## v0.5.0 (2021-08-12)

### Feat

- **compilation**: `Success#executable`

### Refactor

- **compilation**: module instead of alias

## v0.4.0 (2021-08-11)

### Refactor

- **api/repositories**: namespace commit routes
- **drivers**: organize local methods, add driver discovery
- **digest**: use library, avoid binary

### Feat

- **api**: add discover_drivers
- **api/client**: add force_recompile argument
- **api/client**: add query
- support local paths
- **cli**: add option to build from a local repo
- **api**: included compilation time in responses

### Fix

- **digest**: proc block syntax error
- **Dockerfile.test**: remove build step
- **digest**: ensure correct calls
- default to new build method
- **config**: add log filters for sensitive params
- **api/driver**: remove redundant constant
- small HTTP type issues
- **client**: correct types for query params
- **digest_cli**: bugs related to argument parsing
- compilation stoppers
- **api:driver**: manually set https reponse (would be good to support merge)

### Perf

- use scry's graph traversal

## v0.2.2 (2021-07-20)

### Fix

- **client**: arg typo

## v0.2.1 (2021-07-20)

### Fix

- **client**: forward request_id for branches

### Feat

- **repository_sore**: get commits for all files referenced by driver
- **digest_cli**: extract requires

## v0.2.0 (2021-07-12)

### Refactor

- pass driver key on compilation

## v0.1.1 (2021-07-09)

### Fix

- **client**: encode filename
- **cli/build**: pass store instead of path
- **cli**: exit 1 on error
- update `Git` interfaces
- **actions**: fixup check for legacy flag
- **drivers**: correct temporary directory logic

### Feat

- **client**: add request_id argument
- **client**: implement a HTTP client
- **compiler**: enable toggle of asdf support
- **api/root**: implement healthcheck and version
- **cli/build**: implement driver compilation CLI
- **s3**: generate a client depedent on credentials
- **cli**: build a CLI on top of Clip
- **driver_store/s3**: implement s3 backed driver store
- api
- **api/driver**: implement builder api and header authentication
- **api/repositories**: implement repository queries
- **repository_store**: implement a simple git interface
- openAPI client generation
- compilation
- **compilation**: compilation via entrypoint works
- **drivers**: independent compilation
- **drivers**: binary store interface
- **compiler**: simplify fetching latest crystal
- **digest**: digest source without installing
- **digest_cli**: add bindings to cli, drastically increase performance
- **digest**: digest files in parallel
- **compiler**: path? to lookup crystal binary
- **compiler**: asdf compiler management
- source and requires ingester
- initial commit

### Refactor

- **client**: remove unused code
- **scripts/build_llvm_ext**: use vars, give sane defaults
- **cli**: move into seperate files
- **api**: ensure openapi helpers used
- **api/repositories**: delegate instead of getter
- **api**: move param definitions to getters
- move builds.cr to driver.cr
- organise logging
- extract digest to seperate app
