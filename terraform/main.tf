provider "google" {
  project = "utility-binder-434801-u8"
  region  = "us-central1"  
  zone    = "us-central1-a" 
}

resource "google_compute_network" "vpc_network" {
  name                    = "changsathien-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "public_subnet" {
  name                     = "changsathien-pub-subnet"
  region                   = "us-central1"
  network                  = google_compute_network.vpc_network.id
  ip_cidr_range            = "10.0.1.0/24"
  private_ip_google_access = false
}

resource "google_compute_subnetwork" "private_subnet" {
  name                     = "changsathien-pri-subnet"
  region                   = "us-central1"
  network                  = google_compute_network.vpc_network.id
  ip_cidr_range            = "10.0.2.0/24"
  private_ip_google_access = true
}

resource "google_compute_instance" "app_instance" {
  name           = "changsathien-instance"
  machine_type   = "e2-medium"
  zone           = "us-central1-a"
  can_ip_forward = false

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.public_subnet.id
    access_config {
      // This allocates a public IP to the instance
    }
  }

  metadata = {
    ssh-keys = "monthol:${file("~/.ssh/changsathien.pub")}"
  }



  metadata_startup_script = <<-EOT
    #! /bin/bash
    sudo apt-get update
    sudo apt-get install -y docker.io
    docker run -d --name flask-app -p 4000:4000 montholch86/flask-app:latest
  EOT

  tags = ["allow-ssh", "allow-4000"]
}

resource "google_compute_firewall" "allow_http" {
  name    = "allow-http-4000"
  network = google_compute_network.vpc_network.id
  allow {
    protocol = "tcp"
    ports    = ["4000"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-4000"]
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.vpc_network.id
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"] # Allow from any IP, adjust as needed for security
  target_tags   = ["allow-ssh"]
}

output "instance_ip" {
  value = google_compute_instance.app_instance.network_interface[0].access_config[0].nat_ip
}
