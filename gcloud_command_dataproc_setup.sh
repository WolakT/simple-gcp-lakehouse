REGION=europe-central2
gcloud dataproc clusters create presto-cluster  --region=${REGION}      --enable-component-gateway \
 --num-workers=2 --worker-machine-type=n1-standard-2 --master-machine-type=n1-standard-2  --master-boot-disk-size=50GB --worker-boot-disk-size=30GB --initialization-actions=gs://987-delta-lake/init.sh
