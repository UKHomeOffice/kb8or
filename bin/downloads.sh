#!/usr/bin/env bash

set -e

function download() {
    URL=$1
    OUTPUT_FILE=$2
    MD5SUM=$3

    until [[ -x ${OUTPUT_FILE} ]] && [[ $(md5sum ${OUTPUT_FILE} | cut -f1 -d' ') == ${MD5SUM} ]]; do
      wget -nv -O ${OUTPUT_FILE} ${URL}
      chmod +x ${OUTPUT_FILE}
    done
}

download https://storage.googleapis.com/kubernetes-release/release/v1.2.2/bin/linux/amd64/kubectl \
         /usr/local/bin/kubectl \
         e5203a62738b6815c34dd1855ba0d7dd

download https://github.com/UKHomeOffice/s3secrets/releases/download/0.1.2/s3secrets_0.1.2_linux_x86_64 \
         /usr/local/bin/s3secrets \
         a0a592be9d38134c4c3295a525ef2414

