REGION=europe-central2
gcloud dataproc clusters create presto-cluster  --region=${REGION}      --enable-component-gateway \
	 --properties ^#^spark:spark.jars.packages=org.apache.spark:spark-avro_2.12:3.1.3,io.delta:delta-core_2.12:1.0.0#spark:spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog#spark:spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension#spark:spark.sql.repl.eagerEval.enabled=True \
	 --optional-components=JUPYTER \
	 --service-account=delta-lake-sa@dataengineering-experiments.iam.gserviceaccount.com \
	 --subnet=delta-lake-network2 \
 --num-workers=2 --worker-machine-type=n1-standard-2 --master-machine-type=n1-standard-2  --master-boot-disk-size=50GB --worker-boot-disk-size=30GB --initialization-actions=gs://234-scripts/be8584a5379b80b3dcff32946b5c6322.sh

