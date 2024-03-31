# HashiCorp Vault cluster on GCE

Use this repository to install Vault on Google Cloud Platform (GCP) VMs

## 2-Step Process (Step 1 - Provision Cloud Infrastructure):

* Run the Terraform scripts that provision a private network (https://cloud.google.com/vpc/docs/vpc)

* An SSH key pair must be generated prior to executing the Terraform scripts as the path to the public key must be provided

* This installation uses [Auo unseal](https://developer.hashicorp.com/vault/docs/concepts/seal#auto-unseal) and a Cloud KMS keyring will have to be [create](https://cloud.google.com/kms/docs/create-key-ring)

```
gcloud kms keyrings create vault-keyring-01 --location us-east1
```

* Note the keyring ID:

```
gcloud kms keyrings describe vault-keyring-01 --location us-east1  

createTime: '2024-03-29T14:11:30.268970187Z'
name: projects/pluralsight-gcp-infrastructure/locations/us-east1/keyRings/vault-keyring-01
```

* The number of Vault nodes can also be modified (usually an odd number) from the default '3'

* Terraform will also deploy 3 Vault VMs and a Bastion Host with connectivity to the public internet via a Cloud NAT

* Execute Terraform (plan):

```
terraform plan -var 'gce_ssh_pub_key_file=~/.ssh/vault_ssh.pub' -var 'vault_node_count=3' -var 'vault_crypto_key=vault-crypto-key-09' -var 'member_account=user:testaccount@gmail.com' -var 'vault_keyring_id=projects/pluralsight-gcp-infrastructure/locations/us-east1/keyRings/vault-keyring-01'
```

* Deploy GCP Resources (apply):

```
terraform apply -var 'gce_ssh_pub_key_file=~/.ssh/vault_ssh.pub' -var 'vault_node_count=3' -var 'vault_crypto_key=vault-crypto-key-09' -var 'member_account=user:testaccount@gmail.com' -var 'vault_keyring_id=projects/pluralsight-gcp-infrastructure/locations/us-east1/keyRings/vault-keyring-01'
```

* The value for the ```member_account``` variable must be provided. This is a GCP User(s) or Service Account who/that will be granted permissions to access the Bastion Host

* The output from running ```terraform apply``` will print the inventory with the address of Vault nodes. Save the inventory details. For example: 

```
[vault]
10.2.0.2
10.2.0.3
10.2.0.4
```

## Step 2 - Initialize Vault on the leader node

* Login to the Bastion Host:

```
gcloud compute ssh vault-bastion
```

* SSH into one of the nodes using the private key (used with the ```terraform apply```):

```
ssh -i vault_ssh vault@10.2.0.2
```

* Set the ```VAULT_ADDR``` variable:

```
export VAULT_ADDR="http://10.2.0.2:8200"
```

* Check the Vault status and it should be 'sealed' and 'not initialized'

* Initialize Vault and copy the recovery keys and root token:

```
vault operator init > /home/vault/vault.creds
```

* Check the status again - Vault should be 'unsealed' and initialized

* Login to Vault using the root token and validate that the other nodes have joined the cluster:

```
vault login

vault operator raft list-peers
```

