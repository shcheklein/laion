from img2dataset import download
import shutil
import os
from pyspark.sql import SparkSession  # pylint: disable=import-outside-toplevel

from pyspark import SparkConf, SparkContext

# Preparation:
#
# - setup EMR:
#   - 10+ instances
#   - c6i.4xlarge, one EBS 300GB
#   - bootsrap: s3://<bucket>/laion/bootstrap/bootsrap.sh
# - build https://github.com/rom1504/img2dataset on the EMR machine
#   with `make build-pex` (don't forget to change Spark version to EMR's in
#   Makefile)
# - put `img2dataset.pex` and `download.py` into s3://<bucket>/laion/bootsrtap
# - make sure that `output_dir` and `url_list` are set correctly and EMR has access to
#   to those locations
#
# Usage (run within tmux on a master machine):
#
# spark-submit --conf "spark.pyspark.python=./img2dataset.pex" --files ./img2dataset.pex --master yarn download.py

def create_spark_session():
    # this must be a path that is available on all worker nodes
    pex_file = "/home/hadoop/img2dataset.pex"

    os.environ['PYSPARK_PYTHON'] = pex_file

    spark = (
        SparkSession.builder
        .config("spark.submit.deployMode", "client") \
        .config("spark.executorEnv.PEX_ROOT", "./.pex")
        .config("spark.executor.cores", "16")
        .config("spark.executor.memory", "16GB")
        .config("spark.executor.memoryOverhead", "6GB")
        .config("spark.task.maxFailures", "100")
        .master("yarn")
        .appName("LAION")
        .getOrCreate()
    )
    return spark

output_dir = "s3://<bucket>/laion/<otuput>"
url_list = "s3://<bucket>/laion/metadata/<metadata>"

spark = create_spark_session()

download(
    processes_count=1, # this is not used with spark, instead one task for each core will be started (nb executor * nb core per executor)
    thread_count=64,
    timeout=2,
    retries=0,
    url_list = url_list,
    image_size=256,
    resize_only_if_bigger=True,
    resize_mode="keep_ratio",
    skip_reencode=True,
    output_folder=output_dir,
    output_format="files", # files is slowest option, up to 10x pefh hit
    input_format="parquet",
    url_col="URL",
    caption_col="TEXT",
    distributor="pyspark",
    number_sample_per_shard=10000,
    oom_shard_count=6,
    incremental_mode="incremental",
    save_additional_columns=["punsafe","pwatermark","similarity","hash"]
)

