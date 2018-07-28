#!/usr/bin/env bash

check_param() {
  local name=$1
  local value=$(eval echo '$'$name)
  if [ "$value" == 'replace-me' ]; then
    echo "environment variable $name must be set"
    exit 1
  fi
}

commit_bbl_state_dir() {
  local input_dir=${1?'Input git repository absolute path is required.'}
  local bbl_state_dir=${2?'BBL state relative path is required.'}
  local output_dir=${3?'Output git repository absolute path is required.'}
  local commit_message=${4:-'Update bbl state.'}

  pushd "${input_dir}/${bbl_state_dir}"
    if [[ -n $(git status --porcelain) ]]; then
      git config user.name "CI Bot"
      git config user.email "ci@localhost"
      git add --all .
      git commit -m "${commit_message}"
    fi
  popd

  shopt -s dotglob
  cp -R "${input_dir}/." "${output_dir}"
}

print_git_state() {
  if [ -d ".git" ] ; then
    echo "--> last commit..."
    TERM=xterm-256color git --no-pager log -1
    echo "---"
    echo "--> local changes (e.g., from 'fly execute')..."
    TERM=xterm-256color git --no-pager status --verbose
    echo "---"
  fi
}

set_up_vagrant_private_key() {
  if [ ! -f "$BOSH_VAGRANT_PRIVATE_KEY" ]; then
    key_path=$(mktemp -d /tmp/ssh_key.XXXXXXXXXX)/value
    echo "$BOSH_VAGRANT_PRIVATE_KEY" > $key_path
    chmod 600 $key_path
    export BOSH_VAGRANT_KEY_PATH=$key_path
  fi
}

retry_command() {
  local retryable_command=$1
  set +e
  for i in {1..10}; do
    $retryable_command
    local status=$?
    if [ $status -ne 0 ]; then
      echo "sleeping 3s"
      sleep 3s
    else
      return 0
    fi
  done
  set -e
  echo "Timed out running command '$retryable_command'"
  return 1
}

load_db_config() {
  local metadata_file=${1?'Metadata file is required.'}
  local iaas_db=${2?'IaaS/DB is required. ($(echo {RDS,GCP}_{MYSQL,POSTRES} ))'}

  local iaas_db_lower_case="$( echo "$iaas_db" | tr '[:lower:]' )"
  local db_lower_case="$( echo ${iaas_db_lower_case} | cut -d'_' -f2 )"

  if [[ "${iaas_db}" == RDS* ]]; then
    # For RDS we need to remove the port number
    declare ${iaas_db}_EXTERNAL_DB_HOST="$(jq -r .${iaas_db_lower_case}_endpoint ${metadata_file} | cut -d':' -f1)"
  else
    declare ${iaas_db}_EXTERNAL_DB_HOST="$(jq -r .${iaas_db_lower_case}_endpoint ${metadata_file})"

    declare ${iaas_db}_EXTERNAL_DB_CA="$(jq -r .${db_lower_case}_ca_cert gcp-ssl-config/${iaas_db_lower_case}.yml)"
    declare ${iaas_db}_EXTERNAL_DB_CLIENT_CERTIFICATE="$(jq -r .${db_lower_case}_client_cert gcp-ssl-config/${iaas_db_lower_case}.yml)"
    declare ${iaas_db}_EXTERNAL_DB_CLIENT_PRIVATE_KEY="$(jq -r .${db_lower_case}_client_key gcp-ssl-config/${iaas_db_lower_case}.yml)"

    export ${iaas_db}_EXTERNAL_DB_CA
    export ${iaas_db}_EXTERNAL_DB_CLIENT_CERTIFICATE
    export ${iaas_db}_EXTERNAL_DB_CLIENT_PRIVATE_KEY
  fi

  declare ${iaas_db}_EXTERNAL_DB_USER="$(jq -r .db_user ${metadata_file})"
  declare ${iaas_db}_EXTERNAL_DB_PASSWORD="$(jq -r .db_password ${metadata_file})"
  declare ${iaas_db}_EXTERNAL_DB_NAME="$(jq -r .db_name ${metadata_file})"

  export ${iaas_db}_EXTERNAL_DB_HOST
  export ${iaas_db}_EXTERNAL_DB_USER
  export ${iaas_db}_EXTERNAL_DB_PASSWORD
  export ${iaas_db}_EXTERNAL_DB_NAME
}
