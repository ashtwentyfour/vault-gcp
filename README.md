# HashiCorp Vault cluster on GCE

Use this repository to install Vault on Google Cloud Platform (GCP) VMs

## 2-Step Process (Step 1 - Provision Cloud Infrastructure):

* Run the Terraform scripts that provision a private network (https://cloud.google.com/vpc/docs/vpc)

* An SSH key pair must be generated prior to executing the Terraform scripts as the path to the public key must be provided

* This installation uses [Auto unseal](https://developer.hashicorp.com/vault/docs/concepts/seal#auto-unseal) and a Cloud KMS keyring will have to be [created](https://cloud.google.com/kms/docs/create-key-ring)

```
gcloud kms keyrings create vault-keyring-01 --location us-east1
```

* The Vault configuration file (```vault.hcl```), the Vault binary (```vault_1.16.0```) and the ```vault.service``` service definition are downloaded from a Cloud Storage bucket. The ```vault.hcl``` template for this cluster:

```
storage "raft" {
  path    = "/opt/vault/data"
  node_id = "NODE_ID"
  retry_join {
    auto_join = "provider=gce tag_value=vault"
    auto_join_scheme = "http" 
  }
}
listener "tcp" {
 address = "0.0.0.0:8200"
 cluster_address = "0.0.0.0:8201"
 tls_disable = 1
}
seal "gcpckms" {
  project    = "GCP_PROJECT"
  region     = "GCP_REGION"
  key_ring   = "GCP_KEYRING"
  crypto_key = "GCP_CRYPTO_KEY"
}

api_addr = "http://NODE_IP:8200"
cluster_addr = "http://NODE_IP:8201"
cluster_name = "CLUSTER_NAME"
ui = true
log_level = "INFO"
disable_mlock = true
```

* This installation of Vault uses the [integrated storage backend (raft)](https://developer.hashicorp.com/vault/docs/configuration/storage/raft)

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

```
vault@vault-vm-0:~$ vault status
Key                      Value
---                      -----
Seal Type                gcpckms
Recovery Seal Type       n/a
Initialized              false
Sealed                   true
Total Recovery Shares    0
Threshold                0
Unseal Progress          0/0
Unseal Nonce             n/a
Version                  1.16.0
Build Date               2024-03-25T12:01:32Z
Storage Type             raft
HA Enabled               true
```

* Initialize Vault and copy the recovery keys and root token:

```
vault operator init > /home/vault/vault.creds
```

* Check the status again - Vault should be 'unsealed' and initialized

```
vault@vault-vm-0:~$ vault status
Key                      Value
---                      -----
Seal Type                gcpckms
Recovery Seal Type       shamir
Initialized              true
Sealed                   false
Total Recovery Shares    5
Threshold                3
Version                  1.16.0
Build Date               2024-03-25T12:01:32Z
Storage Type             raft
Cluster Name             gce-cluster-01
Cluster ID               848c74a4-4810-795a-6d60-ec0fc1ca7a49
HA Enabled               true
HA Cluster               https://10.2.0.2:8201
HA Mode                  active
Active Since             2024-04-01T02:23:12.774832565Z
Raft Committed Index     57
Raft Applied Index       57
```

* Login to Vault using the root token and validate that the other nodes have joined the cluster - [reference](https://developer.hashicorp.com/vault/tutorials/day-one-raft/raft-deployment-guide#raft-configuration):

```
vault@vault-vm-0:~$ vault login
Token (will be hidden): 
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                  Value
---                  -----
token                hvs.xxxx
token_accessor       xxxx
token_duration       ∞
token_renewable      false
token_policies       ["root"]
identity_policies    []
policies             ["root"]

vault@vault-vm-0:~$ vault operator raft list-peers
Node          Address          State       Voter
----          -------          -----       -----
vault-vm-0    10.2.0.2:8201    leader      true
vault-vm-2    10.2.0.4:8201    follower    true
vault-vm-1    10.2.0.3:8201    follower    true
```

* Test Vault by creating a test secret key-value pair:

```
vault@vault-vm-0:~$ vault secrets enable -path=secret/ kv
Success! Enabled the kv secrets engine at: secret/

vault@vault-vm-0:~$ vault kv put secret/foo bar=baz
Success! Data written to: secret/foo

vault@vault-vm-0:~$ vault kv get -format=json secret/foo
{
  "request_id": "9623de4d-290e-cf00-afbf-77fcc64c96aa",
  "lease_id": "",
  "lease_duration": 2764800,
  "renewable": false,
  "data": {
    "bar": "baz"
  },
  "warnings": null,
  "mount_type": "kv"
}
```
