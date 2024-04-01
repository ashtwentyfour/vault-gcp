provider "google" {
  region      = var.location
  project     = var.project
  credentials = "./gcp/key-file.json"
}

terraform {
  required_version = ">= 1.3.8" 

  required_providers {
    google = {
      source = "google"
      version = "4.79.0"
    }
  }
}
