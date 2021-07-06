#! /usr/bin/env bash

set -eu

docker run --rm -v "${PWD}:/local" openapitools/openapi-generator-cli \
    generate \
        -i /local/openapi.yml \
        -g crystal \
        -o /local/src/placeos-build/client
