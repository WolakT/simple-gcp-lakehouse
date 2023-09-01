terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.80.0"
    }
  }
}

provider "google" {
  project = "mlops-explore" # Configuration options
  region  = "europe-central2"
}


resource "google_service_account" "delta-lake-sa" {
  account_id   = "delta-lake-sa"
  display_name = "Service Account"
}

resource "google_project_iam_member" "dataproc-worker-role" {
  project = "mlops-explore"
  role    = "roles/dataproc.worker"
  member  = "serviceAccount:${google_service_account.delta-lake-sa.email}"
}

resource "google_storage_bucket" "dataproc-staging" {
  name          = "987-dataproc-staging"
  location      = "europe-central2"
  force_destroy = true

  public_access_prevention = "enforced"
}

resource "google_dataproc_cluster" "delta-lake-cluster" {
  name                          = "delta-lake-cluster"
  region                      = "europe-central2"
  graceful_decommission_timeout = "120s"

  cluster_config {
    staging_bucket = google_storage_bucket.dataproc-staging.name

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
        num_local_ssds    = 1
      }
    }

    preemptible_worker_config {
      num_instances = 0
    }

    # Override or set some custom properties
    software_config {
      image_version = "2.0.74-debian10"
      override_properties = {
        "dataproc:dataproc.allow.zero.workers" = "true"
      }
    }


    # You can define multiple initialization_action blocks
    initialization_action {
      script      = "gs://987-delta-lake/init.sh"
      timeout_sec = 500
    }
  }
}
