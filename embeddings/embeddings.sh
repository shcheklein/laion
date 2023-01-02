#!/bin/bash

set -u
set -e
set -o pipefail

# A script to download LAION embeddings in parallel
#
# Based on https://laion.ai/blog/laion-5b/ (Download the data)
#
# - Use dedicated EC2 instance, with high network bandwith to make it faster
# - It should be taking an hour to download everything
#
# Usage example for normal dataset:
#
# ./embeddings.sh laion2B-en > commands
# cat commands | xargs -n 2 -P 50 ../utils/single.sh s3://<bucket>
#
# It will upload missing parts to the s3://<bucket>/laion/embeddings/path/...
# Run the same command a few times in a row to make sure that everything is
# downloaded.


PREFIX=$1

for i in {0000..2313}; do
  echo "https://mystic.the-eye.eu/public/AI/cah/laion5b/embeddings/$PREFIX/$PREFIX-metadata/metadata_${i}.parquet laion/embeddings/$PREFIX/$PREFIX-metadata/metadata_${i}.parquet"
  echo "https://mystic.the-eye.eu/public/AI/cah/laion5b/embeddings/$PREFIX/img_emb/img_emb_${i}.npy laion/embeddings/$PREFIX/img_emb/img_emb_${i}.npy"
  echo "https://mystic.the-eye.eu/public/AI/cah/laion5b/embeddings/$PREFIX/text_emb/text_emb_${i}.npy laion/embeddings/$PREFIX/text_emb/text_emb_${i}.npy"
done

