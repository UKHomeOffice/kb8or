#!/usr/bin/env bash

set -e

function download() {
    URL=$1
    OUTPUT_FILE=$2
    SHA256SUM=$3

    until [[ -x ${OUTPUT_FILE} ]] && [[ $(sha256sum ${OUTPUT_FILE} | cut -f1 -d' ') == ${SHA256SUM} ]]; do
      wget -O ${OUTPUT_FILE} ${URL}
      chmod +x ${OUTPUT_FILE}
    done
}

download https://storage.googleapis.com/kubernetes-release/release/v1.3.5/bin/linux/amd64/kubectl \
         /usr/local/bin/kubectl \
         43e299098a0faef74d2100285325911e8e118c64f5a734b590779ef62ab6a0bb

download https://github.com/UKHomeOffice/s3secrets/releases/download/0.1.2/s3secrets_0.1.2_linux_x86_64 \
         /usr/local/bin/s3secrets \
         a60c9dadd9f9164e4b9598bb3bea3cb7c5e813ad199797f74649c2e642e59c5a
