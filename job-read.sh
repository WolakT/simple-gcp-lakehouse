gcloud dataproc jobs submit pyspark ./spark-read.py --cluster=delta-lake-cluster --region=europe-central2 \
-- gs://234-lakehouse/from_job-table2-presto \

