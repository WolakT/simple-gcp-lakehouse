variable "project" {
  type    = string
  default = "production0987"
}

variable "services" {
  type = list(string)
  default = ["compute.googleapis.com", "dataproc.googleapis.com", "cloudbuild.googleapis.com",
    "sql-component.googleapis.com", "sqladmin.googleapis.com", "datastream.googleapis.com",
  "cloudresourcemanager.googleapis.com", "servicenetworking.googleapis.com"]
}

variable "dataproc_staging_bucket" {
  type    = string
  default = "234-dataproc-staging-bucket"
}

variable "lakehouse_bucket" {
  type    = string
  default = "234-lakehouse"
}

variable "scripts_bucket" {
  type    = string
  default = "234-scripts"
}

variable "region" {
  type    = string
  default = "europe-central2"
}
