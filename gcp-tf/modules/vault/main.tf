resource "google_compute_instance" "vault_vm" {

  name         = var.vault_vm_name
  machine_type = var.machine_type
  zone         = var.availability_zone

  boot_disk {
    initialize_params {
      image = var.image
    }
  }

  metadata_startup_script = <<SCRIPT
    sudo mkdir -p /opt/vault/data
    sudo mkdir -p /etc/vault.d
    sudo chown -R vault:vault /opt/vault
    cd /etc/systemd/system && sudo wget "https://storage.googleapis.com/${var.vault_storage_bucket}/config/vault.service"
    cd /usr/local/bin && sudo wget "https://storage.googleapis.com/${var.vault_storage_bucket}/binary/vault_${var.vault_version}"
    sudo mv "/usr/local/bin/vault_${var.vault_version}" /usr/local/bin/vault
    sudo chmod +x /usr/local/bin/vault
    cd /etc/vault.d && sudo wget "https://storage.googleapis.com/${var.vault_storage_bucket}/config/vault.hcl"
    export IP_ADDRESS=$(hostname -I)
    export PROJECT="${var.vault_project}"
    export REGION="${var.vault_region}"
    export KEYRING="${var.vault_keyring}"
    export CRYPTO_KEY="${var.vault_crypto_key}"
    export NODE_ID="${var.vault_vm_name}"
    export CLUSTER="${var.vault_cluster}"
    sudo sed -i "s|NODE_IP|$${IP_ADDRESS// /}|g" /etc/vault.d/vault.hcl
    sudo sed -i "s|GCP_PROJECT|$${PROJECT}|g" /etc/vault.d/vault.hcl
    sudo sed -i "s|GCP_REGION|$${REGION}|g" /etc/vault.d/vault.hcl
    sudo sed -i "s|GCP_KEYRING|$${KEYRING}|g" /etc/vault.d/vault.hcl
    sudo sed -i "s|GCP_CRYPTO_KEY|$${CRYPTO_KEY}|g" /etc/vault.d/vault.hcl
    sudo sed -i "s|NODE_ID|$${NODE_ID}|g" /etc/vault.d/vault.hcl
    sudo sed -i "s|CLUSTER_NAME|$${CLUSTER}|g" /etc/vault.d/vault.hcl
    sudo systemctl start vault

  SCRIPT

  network_interface {
    network = var.network
    subnetwork = var.subnetwork
  }

  metadata = {
    ssh-keys = "${var.vault_gce_ssh_user}:${file(var.gce_ssh_pub_key_file)}"
  }

  service_account {
    email  = var.vault_kms_service_account
    scopes = ["cloud-platform", "compute-rw", "userinfo-email", "storage-ro"]
  }

  tags = ["vault"]

  labels = var.labels

}

