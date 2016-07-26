#!/usr/bin/env bash

set -e

function download() {
    URL=$1
    OUTPUT_FILE=$2
    MD5SUM=$3

    until [[ -x ${OUTPUT_FILE} ]] && [[ $(md5sum ${OUTPUT_FILE} | cut -f1 -d' ') == ${MD5SUM} ]]; do
      wget -O ${OUTPUT_FILE} ${URL}
      chmod +x ${OUTPUT_FILE}
    done
}

download https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kubectl \
         /usr/local/bin/kubectl \
         09cdb4e370cb5bc77428550ee5a2cf71

download https://github.com/UKHomeOffice/s3secrets/releases/download/0.1.2/s3secrets_0.1.2_linux_x86_64 \
         /usr/local/bin/s3secrets \
         a0a592be9d38134c4c3295a525ef2414
