# Copyright 2022 Google LLC.
# SPDX-License-Identifier: Apache-2.0
import sys
#from delta import *

from pyspark.sql import functions as f
from pyspark import SparkConf
from pyspark.sql import SparkSession


def main():
    input = sys.argv[1]
    print("Starting job: GCS Bucket: ", input)
#    spark = SparkSession\
#        .builder\
#        .appName("DeltaTest")\
#        .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")\
#        .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog")\
#        .getOrCreate()
    conf = SparkConf()
    conf.set("spark.jars.packages", "io.delta:delta-core:1.0.0")
    conf.set("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
    conf.set(
        "spark.sql.catalog.spark_catalog",
        "org.apache.spark.sql.delta.catalog.DeltaCatalog",
    )
    spark = SparkSession.builder.appName("bq_test").config(conf=conf).getOrCreate()
    data = spark.range(0, 500)
    data.write.format("delta").mode("append").save(input)
    df = spark.read \
    .format("delta") \
    .load(input)
    df.show()
    spark.stop()

if __name__ == "__main__":
    main()
