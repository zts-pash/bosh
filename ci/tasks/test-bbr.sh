#!/usr/bin/env bash

set -eu

source bosh-src/ci/tasks/utils.sh

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
src_dir="${script_dir}/../../.."

"${src_dir}/bosh-src/ci/docker/main-bosh-docker/start-bosh.sh"

source /tmp/local-bosh/director/env

bosh int /tmp/local-bosh/director/creds.yml --path /jumpbox_ssh/private_key > /tmp/jumpbox_ssh_key.pem
chmod 400 /tmp/jumpbox_ssh_key.pem

export BOSH_DIRECTOR_IP="10.245.0.3"

BOSH_BINARY_PATH=$(which bosh)
export BOSH_BINARY_PATH
export BOSH_RELEASE="${PWD}/bosh-src/src/spec/assets/dummy-release.tgz"
export BOSH_DIRECTOR_RELEASE_PATH="${PWD}/bosh-release"
CANDIDATE_STEMCELL_TARBALL_PATH="$(realpath "${src_dir}"/stemcell/*.tgz)"
export CANDIDATE_STEMCELL_TARBALL_PATH
export BOSH_DEPLOYMENT_PATH="/usr/local/bosh-deployment"

export OUTER_BOSH_ENV_PATH="/tmp/local-bosh/director/env"

mkdir -p bbr-binary
export BBR_VERSION=1.2.2
curl -L -o bbr-binary/bbr https://s3.amazonaws.com/bosh-dependencies/bbr-$BBR_VERSION

export BBR_SHA256=829160a61a44629a2626b578668777074c7badd75a9b5dab536defdbdd84b17a
export BBR_BINARY_PATH="${PWD}/bbr-binary/bbr"

echo "${BBR_SHA256} ${BBR_BINARY_PATH}" | sha256sum -c -

chmod +x "${BBR_BINARY_PATH}"

cp "${BBR_BINARY_PATH}" /usr/local/bin/bbr

DOCKER_CERTS="$(bosh int /tmp/local-bosh/director/bosh-director.yml --path /instance_groups/0/properties/docker_cpi/docker/tls)"
export DOCKER_CERTS
DOCKER_HOST="$(bosh int /tmp/local-bosh/director/bosh-director.yml --path /instance_groups/name=bosh/properties/docker_cpi/docker/host)"
export DOCKER_HOST


bosh -n update-cloud-config \
  "${BOSH_DEPLOYMENT_PATH}/docker/cloud-config.yml" \
  -o "${src_dir}/bosh-src/ci/docker/main-bosh-docker/outer-cloud-config-ops.yml" \
  -v network=director_network

bosh -n upload-stemcell $CANDIDATE_STEMCELL_TARBALL_PATH

if [ -d database-metadata ]; then
  load_db_config "database-metadata/metadata" "RDS_MYSQL"
  load_db_config "database-metadata/metadata" "RDS_POSTGRES"
  load_db_config "database-metadata/metadata" "GCP_MYSQL"
  load_db_config "database-metadata/metadata" "GCP_POSTGRES"
fi

pushd bosh-src > /dev/null
  scripts/test-bbr
popd > /dev/null
