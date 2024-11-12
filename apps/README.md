These are the steps:

1.  After creating an eks cluster, run this command `aws eks update-kubeconfig --name <cluster-name>` to update your .kube/config file. The next stage is going to need that
2.  Then run terraform init, terraform plan and terraform apply - this deploys vault via helm into the cluster and it's accessible via a loadbalancer. check endpoint with kubectl get svc -n vault

After these steps you the need to unseal vault.

These are the commands:
kubectl -n vault exec vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json > cluster-keys.json
export VAULT_UNSEAL_KEY=$(jq -r ".unseal_keys_b64[]" cluster-keys.json)
kubectl -n vault exec vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY
export CLUSTER_ROOT_TOKEN=$(jq -r ".root_token" cluster-keys.json)
kubectl -n vault exec vault-0 -- vault login $CLUSTER_ROOT_TOKEN
kubectl -n vault exec vault-1 -- vault operator raft join http://vault-0.vault-internal:8200
kubectl -n vault exec vault-1 -- vault operator unseal $VAULT_UNSEAL_KEY
kubectl -n vault exec vault-2 -- vault operator raft join http://vault-0.vault-internal:8200
kubectl -n vault exec vault-2 -- vault operator unseal $VAULT_UNSEAL_KEY

Or if you prefer to use jenkins to run the tasks:
Move to jenkins folder in apps/jenkins and run terraform init, terraform plan and terraform apply
this deploys jenkins via helm in the cluster and creates a sa and binds the sa to a cluster role binding
username and password are in values.yaml file

after jenkins initializes then you can use the jenkinsfile to run the commands to unseal vault.
