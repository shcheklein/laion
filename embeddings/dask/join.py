from dask_kubernetes import HelmCluster
from dask.distributed import Client, as_completed
import s3fs
import numpy as np
import pandas as pd
import pyarrow.parquet as pq
import pyarrow as pa
import pathlib


BUCKET_PATH = "s3://<bucket>/laion/embeddings/laion2B-en"
OUTPUT = "text_emb_joined"
WRITE_BATCH_SIZE = 10000


def transform_to_parquet(file):
    s3 = s3fs.S3FileSystem()
    part_idx = pathlib.Path(s3.split_path(file)[1]).stem.split('_')[-1]
    meta_file = BUCKET_PATH + "/laion2B-en-metadata/metadata_" + part_idx + ".parquet"
    dst = BUCKET_PATH + "/" + OUTPUT + "/" + pathlib.Path(s3.split_path(file)[1]).with_suffix(".parquet").name
    if s3.exists(dst):
        return 0

    f = s3.open(file)
    emd = np.load(f)
    m = s3.open(meta_file)
    meta = pq.read_table(m)

    pqwriter = None
    for start in range(0, emd.shape[0], WRITE_BATCH_SIZE):
        end = min(emd.shape[0], start + WRITE_BATCH_SIZE)
        meta_batch = meta.slice(offset=start, length=WRITE_BATCH_SIZE)
        emd_batch = emd[start:end].tolist()
        partition = pa.Table.from_arrays(
                [c.to_pylist() for c in meta_batch.columns] + [emd_batch] + [[int(part_idx)] * len(emd_batch)] + [range(start, end)],
                names=meta.schema.names + ['v', 'part_idx', 'idx']
            )
        if pqwriter is None:
            pqwriter = pq.ParquetWriter(dst, partition.schema)
        pqwriter.write_table(partition)

    pqwriter.close()
    f.close()
    m.close()
    return emd.shape[0]


cluster = HelmCluster("dask")
client = Client(cluster)
cluster.scale(900)
client.wait_for_workers(900, timeout=1000)


fs = s3fs.S3FileSystem()
files = fs.glob(BUCKET_PATH + "/text_emb/*.npy")
key = ["transform-" + pathlib.Path(fs.split_path(f)[1]).name for f in files]
futures = client.map(transform_to_parquet, files, key=key)
for future in as_completed(futures):
    try:
        res = future.result()
    except Exception as e:
        res = "error: " + str(e)
    print(f"Got result of {future.key}: {res}")

