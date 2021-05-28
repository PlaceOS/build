# PlaceOS Build Service

[![CI](https://github.com/PlaceOS/build/actions/workflows/ci.yml/badge.svg)](https://github.com/PlaceOS/build/actions/workflows/ci.yml)

A service/tool for reproducibly compiling and caching build artefacts.

## CLI

### Build

The binary also exposes the build tool via a CLI, for use in CI pipelines

### Digest

```
Usage: digest_cli [<crystal entrypoint>]

Outputs a CSV of digested crystal sourcegraphs, formatted as FILE,HASH
Expects CRYSTAL_PATH and CRYSTAL_LIBRARY_PATH in the environment

    -s PATH, --shard-lock=PATH       Specify a shard.lock
    -v, --verbose                    Enable verbose logging
    -h, --help                       Show this help
```

## HTTP API

### Repository Metadata

#### `GET /repository?url=[repository url]&count=[commit count: 50]`

Returns the commits for a repository.

#### `GET /repository/<file>?url=[repository url]&count=[commit count: 50]`

Returns the commits for a file.

### Build Artefacts

#### `POST /build/<file>?url=<repository url>&commit=<commit hash>`

Triggers a build of object with <file> as the entrypoint
Returns…
- 200 if compiled
- 500 if the object failed to compile
- 404 if entrypoint was not found

#### `GET /build/<file>/metadata?url=<repository url>&commit=<commit hash>`

#### `GET /build/<file>/docs?url=<repository url>&commit=<commit hash>`

#### `GET /build/<file>/compiled?url=<repository url>&commit=<commit hash>`

Returns...
- 200 if compiled
- 404 not compiled

## Dependencies

- [asdf](https://asdf-vm.com/)
- [curl](https://curl.se/)
- [git](https://git-scm.com/)

## Contributors

- [Caspian Baska](https://github.com/caspiano) - creator and maintainer
