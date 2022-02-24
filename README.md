# PlaceOS Build Service

[![Build](https://github.com/PlaceOS/build/actions/workflows/build.yml/badge.svg)](https://github.com/PlaceOS/build/actions/workflows/build.yml)
[![CI](https://github.com/PlaceOS/build/actions/workflows/ci.yml/badge.svg)](https://github.com/PlaceOS/build/actions/workflows/ci.yml)
[![Docker](https://img.shields.io/badge/Images-dockerhub-github.svg)](https://hub.docker.com/r/placeos/build)
[![Changelog](https://img.shields.io/badge/Changelog-available-github.svg)](/CHANGELOG.md)

A service/tool for reproducibly compiling and caching build artefacts.

## CLI

### Build

```shell-session
$ ./bin/build build --help
Usage: ./bin/build build [OPTIONS]

Run as a CLI. Mainly for use in continuous integration.

Options:
  -v, --version                   Display the application version
                                  [default: false]
  --branch TEXT                   Branch to checkout  [required]
  --commit TEXT                   Commit to check the file out to  [required]
  --repository-uri TEXT           URI of the git repository  [required]
  --discover / --no-discover      Discover drivers and compile them
                                  [default: false]
  --strict-driver-info / --no-strict-driver-info
                                  Extract driver info on build  [default: true]
  --password TEXT                 Password for git repository
  --username TEXT                 Username for git repository
  --binary-store-path TEXT        Where the binaries are mounted
                                  [default: BINARY_STORE_PATH]
  --repository-store-path TEXT    Where the git repositories are mounted
                                  [default: REPOSITORY_STORE_PATH]
  --crystal-version TEXT          Varying this is currently unsupported
                                  [default: CRYSTAL_VERSION]
  --repository-path TEXT          Path to existing repository
  --aws-s3-bucket TEXT            [default: AWS_S3_BUCKET]
  --aws-secret TEXT               [default: AWS_SECRET]
  --aws-key TEXT                  [default: AWS_KEY]
  --aws-region TEXT               [default: AWS_REGION]
  -e, --env                       List the application environment
                                  [default: false]
  --entrypoints TEXT              Driver entrypoints relative to specified
                                  repository  [default: [] of String]
  --help                          Show this message and exit.
```

### Server

```shell-session
$ ./bin/build server --help
Usage: ./bin/build server [OPTIONS]

Run as a REST API, see <TODO: link to openapi.yml>

Options:
  -v, --version          Display the application version  [default: false]
  -e, --env              List the application environment  [default: false]
  --aws-region TEXT      [default: AWS_REGION]
  --aws-key TEXT         [default: AWS_KEY]
  --aws-secret TEXT      [default: AWS_SECRET]
  --aws-s3-bucket TEXT   [default: AWS_S3_BUCKET]
  --host TEXT            Specifies the server host  [default: 127.0.0.1]
  --port INTEGER         Specifies the server port  [default: 3000]
  -w, --workers INTEGER  Specifies the number of processes to handle requests
                         [default: 1]
  -r, --routes           List the application routes  [default: false]
  -c, --curl TEXT        Perform a basic health check by requesting the URL
  --help                 Show this message and exit.
```

### Digest

```shell-session
$ ./bin/digest digest --help
Usage: ./bin/digest digest [OPTIONS] ENTRYPOINTS...

Outputs a CSV of digested crystal source graphs, formatted as FILE,HASH

Arguments:
  ENTRYPOINTS  [required]

Options:
  -s, --shard-lock TEXT  Specify a shard.lock
  -v, --verbose          Enable verbose logging  [default: false]
  --help                 Show this message and exit.
```

### Requires

```shell-session
$ ./bin/digest requires --help
Usage: ./bin/digest requires [OPTIONS] ENTRYPOINTS...

Outputs a list of crystal files in a source graphs, one file per line

Arguments:
  ENTRYPOINTS  [required]

Options:
  -s, --shard-lock TEXT  Specify a shard.lock
  --help                 Show this message and exit.
```

## HTTP API

### Repository Metadata

#### `GET /repository/commits?url=[repository url]&count=[commit count: 50]`

Returns the commits for a repository.

#### `GET /repository/commits/<file>?url=[repository url]&count=[commit count: 50]`

Returns the commits for a file.

#### `GET /repository/discover/drivers?url=[repository url]&branch=[master]&commit=[HEAD]`

Returns an array of files containing driver implementations for a repository.

#### `GET /repository/branches?url=[repository url]`

Returns the branches for a repository

### Driver Artefacts

#### `POST /build/driver/<file>?url=<repository url>&commit=<commit hash>`

Triggers a build of object with <file> as the entrypoint
Returns…
- 200 if compiled
- 404 if entrypoint was not found
- 422 if the object failed to compile

#### `GET /build/driver/<file>/metadata?url=<repository url>&commit=<commit hash>`

Returns the metadata extracted from the built artefact.

#### `GET /build/driver/<file>/docs?url=<repository url>&commit=<commit hash>`

Returns the docs extracted from the artefact.

#### `GET /build/driver?file=<driver entrypoint>&commit=<commit hash>&crystal_version=<version>&digest=<SHA-1 digest>`

Query the driver store for driver binaries.

#### `GET /build/driver/<file>/compiled?url=<repository url>&commit=<commit hash>`

Returns...
- 200 if compiled
- 404 not compiled

## Contributing

See [`CONTRIBUTING.md`](./CONTRIBUTING.md).

## Contributors

- [Caspian Baska](https://github.com/caspiano) - creator and maintainer
