#!/bin/bash

set -e
set -u

export VERSION=$( cat version/number | sed 's/\.0$//;s/\.0$//' )

echo "stable-${VERSION}" > version-tag/tag

echo "Done"
