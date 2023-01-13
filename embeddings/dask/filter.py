from dask_kubernetes import HelmCluster
from dask.distributed import Client, as_completed
import dask.dataframe as dd
import s3fs
import pyarrow.parquet as pq


WORKERS=10
OUTPUT="s3://<bucket>/laion/embeddings/laion2B-en/50k/filter"


def setup_logging():
    import logging
    logger = logging.getLogger("distributed.worker")
    logger.setLevel(logging.DEBUG)
    logger.info("testing")
    logger.debug("debug")


def dump_partition(partition):
    s3 = s3fs.S3FileSystem()
    part_idx = int(partition.head(1).part_idx)
    dst = f"{OUTPUT}/filter_{part_idx:04}.parquet"
    if s3.exists(dst):
        return -1
    if partition.shape[0] == 0:
        return 0
    partition.to_parquet(dst)
    return partition.shape[0]


cluster = HelmCluster("dask")
client = Client(cluster)
cluster.scale(WORKERS)
client.wait_for_workers(WORKERS, timeout=100)
client.register_worker_callbacks(setup_logging)


urls = dd.read_parquet("s3://<metadata>", columns=["url"])
embd = dd.read_parquet("s3://<bucket>/laion/embeddings/laion2B-en/text_emb_joined/text_emb_0001.parquet", columns=["url", "part_idx", "idx"], split_row_groups=70)

result = urls.merge(embd, how="inner", on=["url"]).compute()

