gcloud dataproc jobs submit pyspark ./spark-test2.py --cluster=delta-lake-cluster --region=europe-central2 \
--jars=file:///usr/lib/delta/jars/delta-core_2.12-1.0.0.jar \
-- gs://234-lakehouse/from_job-table2-presto \

