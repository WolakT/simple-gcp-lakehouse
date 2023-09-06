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
    conf.set("spark.jars.packages", "io.delta:delta-core:1.0.0,org.apache.spark:spark-avro_2.12:3.1.3")
    conf.set("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
    conf.set(
        "spark.sql.catalog.spark_catalog",
        "org.apache.spark.sql.delta.catalog.DeltaCatalog",
    )
    input = "gs://234-lakehouse/cover_type_test_table/2023/09/05/11/04/ec8b627ac23dd5ca51705f57b0f7096f8a2c186f_mysql-cdc-binlog_1296257282_6_0.avro"
    spark = SparkSession.builder.appName("bq_test").config(conf=conf).getOrCreate()
    df = spark.read.format('avro').load(input)
    df.show()
    one_row = df.select('payload.*')
    one_row.write.format("delta").mode('append').save("gs://234-lakehouse/read_job")
    delta = spark.sql("select * from delta.`gs://234-lakehouse/read_job`")
    delta.show()
    spark.stop()

if __name__ == "__main__":
    main()
