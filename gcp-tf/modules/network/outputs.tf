output "vault_network" {
  value = google_compute_network.vault_network.id
}

output "vault_subnetwork" {
  value = google_compute_subnetwork.vault_subnetwork.id
}

output "bastion_subnetwork" {
  value = google_compute_subnetwork.bastion_subnetwork.id
}

output "bastion_cloud_nat" {
  value       = module.cloud-nat.name
}
