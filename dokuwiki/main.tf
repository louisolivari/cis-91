variable "credentials_file" { 
  default = "/home/lolivariii/data-plateau-361922-19aff60ce5de.json" 
}

variable "project" {
  default = "data-plateau-361922"
}

variable "region" {
  default = "us-central1"
}

variable "zone" {
  default = "us-central1-c"
}

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.5.0"
    }
  }
}

provider "google" {
  credentials = file(var.credentials_file)
  region  = var.region
  zone    = var.zone 
  project = var.project
}

#
# Network Configuration
#

resource "google_compute_network" "vpc_network" {
  name = "dokuwiki-network"
}

#
# Firewall Config
#

resource "google_compute_firewall" "default-firewall" {
  name = "dokuwiki-firewall"
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "tcp"
    ports = ["22", "80"]
  }
  source_ranges = ["0.0.0.0/0"]
}

#
# Instances
#

resource "google_compute_instance" "vm_instance" {
  name         = "dokuwiki"
  machine_type = "e2-micro"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
    }
  }

#
# Additional Disk
#

  attached_disk {
      source = google_compute_disk.dokuwiki_disk.self_link
      device_name = "dokuwiki-disk"
  }

#
# Service Account
#

  service_account {
    email  = google_service_account.lab08-service-account.email
    scopes = ["cloud-platform"]
  }
}

resource "google_service_account" "lab08-service-account" {
  account_id   = "lab08-service-account"
  display_name = "lab08-service-account"
  description = "Service account for lab 08"
}

resource "google_project_iam_member" "project_member" {
  role = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.lab08-service-account.email}"
}

#
# Storage Bucket
#

resource "google_storage_bucket" "louis-dokuwiki-bucket" {
    name = "louis-dokuwiki-bucket"
    location = "US"

    lifecycle_rule {
        condition {
            age = 180
        }
        action {
            type = "Delete"
        }
    }
}

#
# Dokuwiki Disk
#

resource "google_compute_disk" "dokuwiki_disk" {
    name = "dokuwiki-disk"
    type = "pd-ssd"
    labels = {
      "environment" = "dev"
    }
    size = "100"
}

#
# Output External IP Address
#

output "external-ip" {
  value = google_compute_instance.vm_instance.network_interface[0].access_config[0].nat_ip
}