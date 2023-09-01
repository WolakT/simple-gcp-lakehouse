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

resource "google_compute_network" "delta-lake-network" {
  name                    = "delta-lake-network2"
  auto_create_subnetworks = false
}

resource "google_compute_firewall" "delta-allow-all-internal" {
  name    = "delta-allow-all-internal"
  network = google_compute_network.delta-lake-network.name

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
  source_ranges = ["0.0.0.0/0"]
}


resource "google_service_account" "reverse-proxy-sa" {
  account_id   = "reverse-proxy-sa"
  display_name = "Reverse proxy Service Account"
}

resource "google_compute_subnetwork" "delta-lake-subnet" {
  name                     = "delta-lake-subnet"
  ip_cidr_range            = "10.2.0.0/16"
  region                   = "europe-central2"
  network                  = google_compute_network.delta-lake-network.id
  private_ip_google_access = true
}
resource "google_compute_instance" "reverse-proxy" {
  name         = "reverse-proxy"
  machine_type = "n1-standard-1"
  zone         = "europe-central2-a"


  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  // Local SSD disk
  scratch_disk {
    interface = "SCSI"
  }

  network_interface {
    network = google_compute_subnetwork.delta-lake-subnet.name

    access_config {
      // Ephemeral public IP
    }
  }


  metadata_startup_script = "echo hi > /test.txt"

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.reverse-proxy-sa.email
    scopes = ["cloud-platform"]
  }
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
  region                        = "europe-central2"
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
      optional_components = ["JUPYTER"]
    }

    endpoint_config {
      enable_http_port_access = "true"
    }


    # You can define multiple initialization_action blocks
    initialization_action {
      script      = "gs://987-delta-lake/init.sh"
      timeout_sec = 500
    }

    gce_cluster_config {
      subnetwork = google_compute_subnetwork.delta-lake-subnet.name
    }
  }
}
