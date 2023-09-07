terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.80.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = "europe-central2"
}

module "project-factory_project_services" {
  source        = "terraform-google-modules/project-factory/google//modules/project_services"
  version       = "14.3.0"
  project_id    = var.project
  activate_apis = var.services
}

module "cloud-nat" {
  source        = "terraform-google-modules/cloud-nat/google"
  version       = "4.1.0"
  project_id    = var.project
  router        = "delta-lake-router"
  region        = var.region
  create_router = true
  network       = google_compute_network.delta_lake_network.id
}

resource "google_compute_global_address" "private_ip_alloc" {
  name          = "private-ip-alloc"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.delta_lake_network.id
}

# Create a private connection
# Allows for communication with managed services
resource "google_service_networking_connection" "default" {
  network                 = google_compute_network.delta_lake_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
}

############################################################################

#                              DATASTREAM SETUP

############################################################################
resource "google_datastream_private_connection" "default" {
  display_name          = "Connection profile"
  location              = var.region
  private_connection_id = "private-connection"

  vpc_peering_config {
    vpc    = google_compute_network.delta_lake_network.id
    subnet = "10.0.0.0/29"
  }
}

resource "google_datastream_connection_profile" "gcs_connection" {
  display_name          = "GCS connection profile"
  location              = var.region
  connection_profile_id = "gcs-connection"

  depends_on   = [module.project-factory_project_services]
  gcs_profile {
    bucket    = google_storage_bucket.lakehouse.name
    root_path = "/"
  }
}

resource "google_datastream_connection_profile" "mysql_connection" {
  display_name          = "MySQL connection profile"
  location              = var.region
  connection_profile_id = "mysql-connection"

  private_connectivity {
    private_connection = google_datastream_private_connection.default.id
  }

  mysql_profile {
    hostname = google_compute_instance.reverse_proxy.network_interface.0.network_ip
    username = google_sql_user.datastream_user.name
    password = google_sql_user.datastream_user.password
    port     = "3306"
    #    database = google_sql_database.db.name
  }
}

resource "google_datastream_stream" "delta_lake_stream" {
  display_name  = "CloudSQL to GCS"
  location      = var.region
  stream_id     = "delta_lake_stream"
  desired_state = "RUNNING"

  source_config {
    source_connection_profile = google_datastream_connection_profile.mysql_connection.id
    mysql_source_config {
      #include_objects {
      #  mysql_databases {
      #    database = "cover_type"
      #    mysql_tables {
      #      table = "table"
      #      mysql_columns {
      #        column = "column"
      #      }
      #    }
      #  }
      #}

    }
  }

  destination_config {
    destination_connection_profile = google_datastream_connection_profile.gcs_connection.id
    gcs_destination_config {
      path = "/"
      avro_file_format {
      }
    }
  }
  backfill_none {}

}


resource "random_password" "pwd" {
  length  = 16
  special = false
}
############################################################################

#                              CLOUDSQL SETUP

############################################################################

resource "google_sql_user" "datastream_user" {
  name     = "datastream-user"
  instance = google_sql_database_instance.instance.name
  password = random_password.pwd.result
}

resource "google_sql_database_instance" "instance" {
  name             = "delta-lake-instance"
  database_version = "MYSQL_8_0"
  region           = var.region
  depends_on   = [module.project-factory_project_services, google_service_networking_connection.default]

  settings {
    backup_configuration {

      binary_log_enabled = "true"
      enabled            = "true"

    }

    tier              = "db-f1-micro"
    availability_type = "REGIONAL"
    disk_size         = 10 # 10 GB is the smallest disk size
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.delta_lake_network.self_link
    }
  }

  deletion_protection = "false"
}

resource "google_sql_database" "cover_type" {
  instance = google_sql_database_instance.instance.name
  name     = "cover_type"
}
############################################################################

#                              NETWORKING SETUP

############################################################################

resource "google_compute_network" "delta_lake_network" {
  name                    = "delta-lake-network2"
  auto_create_subnetworks = false
  depends_on   = [module.project-factory_project_services]
}

resource "google_compute_subnetwork" "delta_lake_subnet" {
  name                     = "delta-lake-subnet"
  ip_cidr_range            = "10.2.0.0/16"
  region                   = "europe-central2"
  network                  = google_compute_network.delta_lake_network.id
  private_ip_google_access = true
}

resource "google_compute_firewall" "delta_allow_all_internal" {
  name    = "delta-allow-all-internal"
  network = google_compute_network.delta_lake_network.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  source_ranges = ["10.0.0.0/8"]
}

resource "google_compute_firewall" "delta_allow_ssh" {
  name    = "delta-allow-ssh"
  network = google_compute_network.delta_lake_network.name


  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  
  source_ranges = ["0.0.0.0/0"]
  target_tags = ["bastion-host"]
}


############################################################################

#                           SERVICE ACCOUNTS SETUP

############################################################################

resource "google_service_account" "reverse_proxy_sa" {
  account_id   = "reverse-proxy-sa"
  display_name = "Reverse proxy Service Account"
}

resource "google_service_account" "delta_lake_sa" {
  account_id   = "delta-lake-sa"
  display_name = "Service Account"
}

resource "google_project_iam_member" "dataproc_worker_role" {
  project = var.project
  role    = "roles/dataproc.worker"
  member  = "serviceAccount:${google_service_account.delta_lake_sa.email}"
}

resource "google_project_iam_member" "dataproc_storage_admin_role" {
  project = var.project
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.delta_lake_sa.email}"
}


############################################################################

#                              COMPUTE SETUP

############################################################################

resource "google_compute_instance" "reverse_proxy" {
  name         = "reverse-proxy"
  machine_type = "n1-standard-1"
  zone         = "europe-central2-a"
  depends_on   = [module.project-factory_project_services]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  // Local SSD disk
  network_interface {
    subnetwork = google_compute_subnetwork.delta_lake_subnet.name
  }
  tags = ["bastion-host"]

  metadata_startup_script = <<-EOT
    #! /bin/bash
    
    export DB_ADDR=${google_sql_database_instance.instance.private_ip_address}
    export DB_PORT=3306
    
    export ETH_NAME=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo)
    
    export LOCAL_IP_ADDR=$(ip -4 addr show $ETH_NAME | grep -Po 'inet \K[\d.]+')
    
    echo 1 > /proc/sys/net/ipv4/ip_forward
    iptables -t nat -A PREROUTING -p tcp -m tcp --dport $DB_PORT -j DNAT \
    --to-destination $DB_ADDR:$DB_PORT
    iptables -t nat -A POSTROUTING -j SNAT --to-source $LOCAL_IP_ADDR
    EOT

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.reverse_proxy_sa.email
    scopes = ["cloud-platform"]
  }
}


############################################################################

#                              STORAGE SETUP

############################################################################
resource "random_string" "staging" {
  length    = 4
  special   = false
  min_lower = 4
}

resource "random_string" "scripts" {
  length    = 4
  special   = false
  min_lower = 4
}

resource "random_string" "lakehouse" {
  length    = 4
  special   = false
  min_lower = 4
}


resource "google_storage_bucket" "dataproc_staging" {
  name          = "${var.dataproc_staging_bucket}-${random_string.staging.result}"
  location      = var.region
  force_destroy = true

  public_access_prevention = "enforced"
}

resource "google_storage_bucket" "scripts" {
  name          = "${var.scripts_bucket}-${random_string.scripts.result}"
  location      = var.region
  force_destroy = true

  public_access_prevention = "enforced"
}

resource "google_storage_bucket" "lakehouse" {
  name          = "${var.lakehouse_bucket}-${random_string.lakehouse.result}"
  location      = var.region
  force_destroy = true

  public_access_prevention = "enforced"
}

data "local_file" "init_script" {
  filename = "../init.sh"
}

resource "google_storage_bucket_object" "init_script" {
  bucket = google_storage_bucket.scripts.name
  source = data.local_file.init_script.filename
  name   = "${data.local_file.init_script.content_md5}.sh"
}

############################################################################

#                              DATAPROC SETUP

############################################################################


resource "google_dataproc_cluster" "delta_lake_cluster" {
  name                          = "delta-lake-cluster"
  region                        = "europe-central2"
  graceful_decommission_timeout = "120s"

  depends_on   = [module.project-factory_project_services]

  cluster_config {
    staging_bucket = google_storage_bucket.dataproc_staging.name

    master_config {
      num_instances = 1
      machine_type  = "n1-standard-2"
      disk_config {
        boot_disk_type    = "pd-ssd"
        boot_disk_size_gb = 40
      }
    }

    worker_config {
      num_instances    = 2
      machine_type     = "n1-standard-2"
      min_cpu_platform = "Intel Skylake"
      disk_config {
        boot_disk_size_gb = 30
      }
    }

    preemptible_worker_config {
      num_instances = 0
    }

    # Override or set some custom properties
    software_config {
      image_version = "2.1.22-debian11"
      override_properties = {
        "spark:spark.jars.packages"              = "org.apache.spark:spark-avro_2.12:3.3.0,io.delta:delta-core_2.12:2.3.0",
        "spark:spark.sql.repl.eagerEval.enabled" = "True",
        "spark:spark.sql.catalog.spark_catalog"  = "org.apache.spark.sql.delta.catalog.DeltaCatalog",
        "spark:spark.sql.extensions"             = "io.delta.sql.DeltaSparkSessionExtension"
        "dataproc:dataproc.allow.zero.workers"   = "false"
      }
      optional_components = ["JUPYTER"]
    }

    #this is needed to access the jupyter UI
    endpoint_config {
      enable_http_port_access = "true"
    }


    # You can define multiple initialization_action blocks
    initialization_action {
      script      = "gs://${google_storage_bucket.scripts.name}/${google_storage_bucket_object.init_script.name}"
      timeout_sec = 500
    }

    gce_cluster_config {
      service_account = google_service_account.delta_lake_sa.email
      subnetwork      = google_compute_subnetwork.delta_lake_subnet.name
    }
  }

}

############################################################################

#                              OUTPUTS

############################################################################


output "reverse_proxy_ip" {
  value = google_compute_instance.reverse_proxy.network_interface.0.network_ip
}

output "sql_private_address" {
  value       = google_sql_database_instance.instance.private_ip_address
  description = "The private IP address assigned for the master instance"
}

output "random_lakehouse" {
  value = random_string.lakehouse.result
}

output "random_scripts" {
  value = random_string.scripts.result
}

output "random_staging" {
  value = random_string.staging.result
}

