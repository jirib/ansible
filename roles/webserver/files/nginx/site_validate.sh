#!/usr/bin/env bash

# this is a wrapper for ansible template task validation option which
# validates individual virtual site configuration which is located in
# separate files

set -eu
set -o pipefail

# args: tpl_file

conf_file=$1
tmpfile=$(mktemp)
trap "rm -f ${tmpfile}" EXIT

[[ -e "${conf_file}" ]]

cat > ${tmpfile} <<EOF
events {
  worker_connections  512;
}
http {
  include ${conf_file};
}
EOF

nginx -t -c ${tmpfile}
