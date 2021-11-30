locals {
  gcp_credentails_path = "gcp-credentials.json"
  gcp_credentails_file = file(local.gcp_credentails_path)
  gcp_credentails = jsondecode(local.gcp_credentails_file)
}

terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.0.0"
    }
  }
}

provider "google" {
  credentials = local.gcp_credentails_file
  project = local.gcp_credentails.project_id
  region = "europe-central2"
  zone = "europe-central2-a"
}

resource "google_compute_address" "static" {
  name = "ipv4-address"
}

# resource "google_compute_image" "nixos_image" {
#   name = "nixos-20-03"
#   family = "nixos"
#   raw_disk {
#     # source = "https://storage.googleapis.com/bosh-gce-raw-stemcells/bosh-stemcell-97.98-google-kvm-ubuntu-xenial-go_agent-raw-1557960142.tar.gz"
#     source = "https://storage.googleapis.com/nixos-images/google-cloud-nixos-20.03.1639.73e73c7d6b5.raw.tar.gz"
#   }
# }

resource "google_compute_network" "server" {
  name = "server-network"
}

resource "google_compute_firewall" "server_engress" {
  name    = "server-firewall-engress"

  network = google_compute_network.server.name
  direction = "EGRESS"

  allow {
    protocol = "all"
  }
}

resource "google_compute_firewall" "server_ingress" {
  name = "server-firewall-ingress"

  network = google_compute_network.server.name
  direction = "INGRESS"
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports = ["25565", "22"]
  }

  allow {
    protocol = "udp"
    ports = ["19132"]
  }
}

resource "google_compute_instance" "server" {
  name = "minecraft-server"
  machine_type = "e2-standard-2"
  zone = "europe-central2-a"
  tags = ["server"]

  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      size = 10
      # image = google_compute_image.nixos_image.self_link
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = google_compute_network.server.name

    access_config {
      nat_ip = google_compute_address.static.address
    }
  }

  lifecycle {
    ignore_changes = [attached_disk]
  }

  metadata_startup_script = file("startup.sh")
}

resource "google_compute_attached_disk" "server" {
  disk = google_compute_disk.server.id
  instance = google_compute_instance.server.id
}

resource "google_compute_disk_resource_policy_attachment" "attachment" {
  name = google_compute_resource_policy.server_snapshot.name
  disk = google_compute_disk.server.name
  zone = "europe-central2-a"
}

resource "google_compute_disk" "server" {
  name  = "server-disk"
  type  = "pd-ssd"
  zone = "europe-central2-a"
  size = 50
}

resource "google_compute_resource_policy" "server_snapshot" {
  name = "disk-policy"
  region = "europe-central2"
  snapshot_schedule_policy {
    schedule {
      hourly_schedule {
        hours_in_cycle = 6
        start_time = "00:00"
      }
    }
    retention_policy {
      max_retention_days = 1
      on_source_disk_delete = "APPLY_RETENTION_POLICY"
    }
  }
}

resource "google_compute_resource_policy" "server_restart" {
  name = "server-policy"
  region = "europe-central2"
  instance_schedule_policy {
    vm_start_schedule {
      schedule = "10 5 * * *"
    }
    vm_stop_schedule {
      schedule = "0 5 * * *"
    }
    time_zone =  "Europe/Warsaw"
  }
}
