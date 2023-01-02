
#!/bin/bash

set -u
set -e
set -o pipefail

# A script to download LAION metadata in parallel
#
# Based on https://github.com/rom1504/img2dataset/blob/main/dataset_examples/laion5B.md
#
# - Use dedicated EC2 instance, with high network bandwith to make it faster
# - It should be taking an hour to download everything
#
# Usage example for normal dataset:
#
# ./metadata.sh laion2B-en 5114fd87-297e-42b0-9d11-50f1df323dfa-c000 path > commands
# ./metadata.sh laion2B-multi fc82da14-99c9-4ff6-ab6a-ac853ac82819-c000 path >> commands
# ./metadata.sh laion1B-nolang d6a94da9-d368-4d5b-9ab7-3f6d3c7abdb3-c000 path >> commands
# cat commands | xargs -n 2 -P 50 ../utils/single.sh s3://<bucket>
#
# It will upload missing parts to the s3://<bucket>/<path>/... .
# Run the same command a few times in a row to make sure that everything is
# downloaded.


PREFIX=$1
HASH=$2
PATH_IN_BUCKET=$3

for i in {00000..00127}; do
  echo "https://huggingface.co/datasets/laion/$PREFIX/resolve/main/part-$i-$HASH.snappy.parquet $PATH_IN_BUCKET/$PREFIX/part-$i-$HASH.snappy.parquet"
done

