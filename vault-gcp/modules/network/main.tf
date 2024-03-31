resource "google_compute_network" "vault_network" {
  name                    = "vault-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "vault_subnetwork" {
  name          = "vault-subnetwork"
  ip_cidr_range = var.cidr_range
  region        = var.location
  network       = google_compute_network.vault_network.id
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "bastion_subnetwork" {
  name          = "bastion-subnetwork"
  ip_cidr_range = var.bastion_cidr_range
  region        = var.location
  network       = google_compute_network.vault_network.id
  private_ip_google_access = true
}

resource "google_compute_firewall" "vault_firewall" {
  name    = "allow-vault"
  network = google_compute_network.vault_network.id

  allow {
    protocol = "tcp"
    ports    = ["22", "8200", "8201"]
  }

  source_ranges = [var.cidr_range, var.bastion_cidr_range]
  target_tags   = ["vault"]
}

module "cloud-nat" {
  source     = "terraform-google-modules/cloud-nat/google"
  version    = "~> 1.2"
  name = "vault-bastion-cloud-nat"
  project_id = var.project
  region     = var.location
  router     = "vault-bastion-cloud-router"
  network       = google_compute_network.vault_network.id
  create_router = true
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetworks = [
    {
      name = google_compute_subnetwork.bastion_subnetwork.id
      source_ip_ranges_to_nat = [var.bastion_cidr_range]
      secondary_ip_range_names = []
    }
  ]
}
