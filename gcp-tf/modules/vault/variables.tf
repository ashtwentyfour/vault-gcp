variable "machine_type" {
  type = string
  default = "e2-medium"
}

variable "image" {
  type = string
  default = "ubuntu-os-cloud/ubuntu-2204-lts"
}

variable "vault_vm_name" {
    type = string
}

variable "vault_region" {
    type = string
}

variable "availability_zone" {
    type = string
}

variable "network" {
    type = string
}

variable "subnetwork" {
    type = string
}

variable "vault_gce_ssh_user" {
    type = string
    default = "vault"
}

variable "gce_ssh_pub_key_file" {
    type = string
}

variable "labels" {
    type = map
}

variable "vault_kms_service_account" {
    type = string
}

variable "vault_storage_bucket" {
    type = string
    default = "vault-ffbd1a28-cb1f-4d01-b904-b4dafcdd08b9"
}

variable "vault_version" {
    type = string 
    default = "1.16.0"
}

variable "vault_project" {
    type = string
}

variable "vault_crypto_key" {
    type = string
}

variable "vault_keyring" {
    type = string
    default = "vault-keyring-01"
}

variable "vault_cluster" {
    type = string
}
