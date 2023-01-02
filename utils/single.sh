#!/bin/bash

set -u
set -e
set -o pipefail

BUCKET=$1
SRC=$2
DST=$3

set +e
aws s3api head-object \
  --bucket $BUCKET \
  --key "$DST" \
  --output json
res=$?
set -eA
if [ "$res"x = "255"x ]; then
  echo "Copying $SRC to s3://$BUCKET/$DST ..."
  wget "$SRC" -O - | aws s3 cp - "s3://$BUCKET/$DST"
fi

