#!/usr/bin/env bash

set -eu

fly -t production set-pipeline \
  -p bosh:os-image:3312.umask.x \
  -c ci/pipelines/os-images/pipeline.yml \
  -v branch=3312.umask.x \
  --load-vars-from <(lpass show -G "concourse:production pipeline:os-images" --notes)
