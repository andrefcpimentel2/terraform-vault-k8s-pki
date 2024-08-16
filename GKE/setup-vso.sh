#! /bin/bash

# test script to run manually steps and k8s yaml files

export GCP_PROJECT_ID=$(terraform output -json project | jq -r)

gcloud config set project $GCP_PROJECT_ID
gcloud components install gke-gcloud-auth-plugin

gcloud container clusters get-credentials \
  $(terraform output -json kubernetes_clusters | jq -r ".[0].kubernetes_cluster_name")  \
    --region $(terraform output -json region | jq -r)

export K8S_URL=$(terraform output -json kubernetes_clusters  | jq -r ".[0].kubernetes_cluster_endpoint") \
  && echo $K8S_URL

kubectl config use-context $(kubectl config get-contexts -o name | grep cluster-1-gke)

kubectl apply -f - <<EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault-auth
---
apiVersion: v1
kind: Secret
metadata:
  name: vault-auth
  annotations:
    kubernetes.io/service-account.name: vault-auth
type: kubernetes.io/service-account-token
---
EOF

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: role-tokenreview-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
  - kind: ServiceAccount
    name: vault-auth
    namespace: default
EOF

VAULTAUTH_SECRET=$(kubectl get secret vault-auth -o json | jq -r '.data') \
  && echo $VAULTAUTH_SECRET


echo $VAULTAUTH_SECRET | jq -r '."ca.crt"' | base64 -d > cluster1_ca.crt

awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' cluster1_ca.crt

VAULTAUTH_TOKEN=$(echo $VAULTAUTH_SECRET | jq -r '.token' | base64 -d) \
  && echo $VAULTAUTH_TOKEN

vault auth enable -path=cluster1 kubernetes

vault write auth/cluster1/config \
 token_reviewer_jwt=$VAULTAUTH_TOKEN \
 kubernetes_host=$K8S_URL \
 kubernetes_ca_cert=@cluster1_ca.crt


vault policy write exampleapp-read - << EOF
path "secret/*" {
  capabilities = ["read"]
}
path "pki_int/*" {
  capabilities = [ "create", "read", "update", "delete", "list", "sudo" ]
}
EOF


vault write auth/cluster1/role/vso \
bound_service_account_names=vault-auth \
bound_service_account_namespaces=default \
policies=default,exampleapp-read \
ttl=1h

helm repo add hashicorp https://helm.releases.hashicorp.com \
    && helm repo update

helm install vault-secrets-operator hashicorp/vault-secrets-operator \
    --namespace vault-secrets-operator \
    --create-namespace 


kubectl apply -f - <<EOF
---
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultConnection
metadata:
  namespace: default
  name: vault-connection
spec:
  # address to the Vault server.
  address: $VAULT_ADDR
---
EOF


kubectl describe vaultconnection.secrets.hashicorp.com/vault-connection

 while ! kubectl describe vaultconnection.secrets.hashicorp.com/vault-connection | grep Accepted 2>/dev/null; do
    sleep 3
  done

kubectl apply -f - <<EOF
---
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultAuth
metadata:
  name: vault-auth
spec:
  vaultConnectionRef: vault-connection
  method: kubernetes
  mount: cluster1
  kubernetes:
    role: vso
    serviceAccount: vault-auth
  namespace: "admin" #Vault Dedicated only
---
EOF


kubectl describe vaultauth.secrets.hashicorp.com/vault-auth

kubectl apply -f - <<EOF
---
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: vault-static-secret
spec:
  vaultAuthRef: vault-auth
  namespace: "admin" #Vault Dedicated only
  mount: secret
  type: kv-v2
  path:  exampleapp/config
# version: 2
  refreshAfter: 300s
  destination:
    create: true
    name: vso-handled
---
EOF


kubectl describe VaultStaticSecret.secrets.hashicorp.com/vault-static-secret


kubectl apply -f - <<EOF
---
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultPKISecret
metadata:
  name: pki1
spec:
  vaultAuthRef: vault-auth
  namespace: "admin" #Vault Dedicated only
  mount: pki_int
  role: example-dot-com
  commonName: test.example.com
  format: pem
  expiryOffset: 1s
  ttl: 60s
  destination:
    create: true
    name: pki1
  rolloutRestartTargets:
  - kind: Deployment
    name: vso-pki-demo
---
EOF

sleep 5
kubectl get secrets
kubectl get secret vso-handled -o json | jq ".data | map_values(@base64d)"
kubectl get secret pki1 -o json | jq ".data | map_values(@base64d)"

kubectl apply -f - <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vso-pki-demo
  labels:
    test: vso-pki-demo
spec:
  replicas: 3
  strategy:
    rollingUpdate:
      maxUnavailable: 1
  selector:
    matchLabels:
      test: vso-pki-demo
  template:
    metadata:
      labels:
        test: vso-pki-demo
    spec:
      volumes:
        - name: secrets
          secret:
            secretName: "pki1"
      containers:
        - name: example
          image: nginx:latest
          volumeMounts:
            - name: secrets
              mountPath: /etc/secrets
              readOnly: true
---
EOF

sleep 5

kubectl exec \
      $(kubectl get pod -l test=vso-pki-demo -o jsonpath="{.items[0].metadata.name}") \
      -- cat /etc/secrets/certificate

# kubectl scale --replicas=5 deployments/vso-pki-demo

kubectl exec \
      $(kubectl get pod -l test=vso-pki-demo -o jsonpath="{.items[4].metadata.name}") \
      -- cat /etc/secrets/certificate