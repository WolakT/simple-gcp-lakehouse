# Notes for future, lessons learned, etc

## Spark

1. Spark configuartion can be found in: etc/spark/conf/spark-defaults.conf

2. It is better to set up a spark cluster and providing needed packages if you are using jupyterLabs the PySpark kernel will be ready and spark will have the needed packages in its context:
`software_config {
      image_version = "2.1.22-debian11"
      override_properties = {
        "spark:spark.jars.packages" = "org.apache.spark:spark-avro_2.12:3.3.0,io.delta:delta-core_2.12:2.3.0",
        "spark:spark.sql.repl.eagerEval.enabled" = "True",
        "spark:spark.sql.catalog.spark_catalog"="org.apache.spark.sql.delta.catalog.DeltaCatalog",
        "spark:spark.sql.extensions"= "io.delta.sql.DeltaSparkSessionExtension"
        "dataproc:dataproc.allow.zero.workers" = "false"
      }
      optional_components = ["JUPYTER"]
    }`
3. You can always submit a job and add packages with the --properties flag


## Terraform

1. Using modules saves work. For example module for services helps in setting up behaviour while destroying the app. See [terraform main file](terraform/main.tf). In this project such module is `module "project-factory_project_services`
 


## GCLOUD command

1. There is option to change the delimiter for gcloud commands. Use ^DELIMITER^ after the flag to change the default delimiter. This is useful if you have comma in the text you want to pass. See example [gcloud command](gcloud_command_dataproc_setup.sh)

2. If changing the delimiter is not enough use use `gcloud topic flags-file` for alternative


