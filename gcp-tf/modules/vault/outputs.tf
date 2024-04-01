output "vault_ip" {
  value = google_compute_instance.vault_vm[*].network_interface[0].network_ip
}
