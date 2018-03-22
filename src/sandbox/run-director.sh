#!/bin/bash -ex

sleep 10

source /etc/profile.d/chruby.sh
chruby 2.4.2
bundle exec bosh-director/bin/bosh-director-migrate -c /config/director_test.yml
bundle exec bosh-director/bin/bosh-director -c /config/director_test.yml
