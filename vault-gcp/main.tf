terraform {
  required_version = ">= 1.0" 
}

locals {
    labels = {
        environment = var.environment
    }
}

resource "google_service_account" "vault_kms_service_account" {

  account_id   = "vault-kms-sa"
  display_name = "Vault KMS for auto-unseal"

}

resource "google_kms_crypto_key" "vault_crypto_key" {

    name            = var.vault_crypto_key
    key_ring        = var.vault_keyring_id
    rotation_period = "100000s"

}

resource "google_kms_key_ring_iam_binding" "vault_iam_kms_binding" {

  key_ring_id = var.vault_keyring_id
  role = "roles/owner"

  members = [
    "serviceAccount:${google_service_account.vault_kms_service_account.email}",
  ]

}

resource "google_project_iam_binding" "vault_iam_gce_binding" {

  project = var.project
  role    = "roles/compute.viewer"
  members = [
    "serviceAccount:${google_service_account.vault_kms_service_account.email}"
  ]

}

module "vault_network" {
    source = "./modules/network"
    location = var.location
    cidr_range = var.cidr_range
    bastion_cidr_range = var.bastion_cidr_range
    project = var.project
}

module "iap_bastion" {
  name = "vault-bastion"
  source = "terraform-google-modules/bastion-host/google"
  version = "5.3.0"
  project = var.project
  zone    = var.availability_zone
  network = module.vault_network.vault_network
  subnet  = module.vault_network.bastion_subnetwork
  members = [var.member_account]
  labels = local.labels
}

module "vault_cluster" {
   source = "./modules/vault"
   count = var.vault_node_count
   vault_vm_name = "vault-vm-${count.index}"
   vault_kms_service_account = google_service_account.vault_kms_service_account.email
   availability_zone = var.availability_zone
   vault_region = var.location
   vault_project = var.project
   vault_version = var.vault_version
   vault_crypto_key = var.vault_crypto_key
   vault_cluster = "gce-cluster-01"
   vault_keyring = "vault-keyring-01"
   network = module.vault_network.vault_network
   subnetwork = module.vault_network.vault_subnetwork
   gce_ssh_pub_key_file = var.gce_ssh_pub_key_file
   labels = local.labels
}

output "bastion_hostname" {
    value = module.iap_bastion.hostname
}

output "vault_ips" {
  value = templatefile("templates/inventory.tftpl", {
    vault_ips = tolist(module.vault_cluster[*].vault_ip[*])
  })
}
