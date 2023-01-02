from dask_kubernetes import HelmCluster
from dask.distributed import Client
import dask.bag as db
import s3fs
import numpy as np
import pandas as pd
import pyarrow.parquet as pq
import pyarrow as pa
import pathlib


BUCKET_PATH = "s3://<bucket>/laion/embeddings/laion2B-en"
OUTPUT = "img_emb_joined"
WRITE_BATCH_SIZE = 10000


def test_consistency(file):
    s3 = s3fs.S3FileSystem()
    f = s3.open(file)
    emd = np.load(f)
    size = emd.shape
    del emd
    f.close()
    dst = BUCKET_PATH + "/" + OUTPUT + "/" + pathlib.Path(s3.split_path(file)[1]).with_suffix(".parquet").name
    t = pq.read_table(dst)
    if t.num_rows == size[0]:
        return 1
    else:
        return 0


def transofrm_to_parquet(file):
    s3 = s3fs.S3FileSystem()
    dst = BUCKET_PATH + "/" + OUTPUT + "/" + pathlib.Path(s3.split_path(file)[1]).with_suffix(".parquet").name
    if s3.exists(dst):
        return 2

    f = s3.open(file)
    emd = np.load(f)

    pqwriter = None
    for start in range(0, emd.shape[0], WRITE_BATCH_SIZE):
        end = min(emd.shape[0], start + WRITE_BATCH_SIZE)
        partition = pa.Table.from_arrays([range(start, end), emd[start:end].tolist()], names=['idx', 'v'])
        if pqwriter is None:
            pqwriter = pq.ParquetWriter(dst, partition.schema)
        pqwriter.write_table(partition)

    pqwriter.close()
    f.close()
    return 1

cluster = HelmCluster("dask")
client = Client(cluster)

cluster.scale(100)
client.wait_for_workers(100, timeout=300)

fs = s3fs.S3FileSystem()
res = db.from_sequence(fs.glob(BUCKET_PATH + "/img_emb/*.npy")).map(test_consistency).compute()

print(res)

cluster.scale(1)
client.wait_for_workers(1, timeout=300)


