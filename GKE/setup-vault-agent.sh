#! /bin/bash

# test script to run manually steps and k8s yaml files

export GCP_PROJECT_ID=$(terraform output -json project | jq -r)
export REGION=$(terraform output -json region | jq -r)
export CLUSTER_NAME=$(terraform output -json kubernetes_clusters | jq -r ".[1].kubernetes_cluster_name")

gcloud config set project $GCP_PROJECT_ID
gcloud components install gke-gcloud-auth-plugin

gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION

export K8S_URL=$(terraform output -json kubernetes_clusters  | jq -r ".[1].kubernetes_cluster_endpoint") \
  && echo $K8S_URL

kubectl config use-context $(kubectl config get-contexts -o name | grep $CLUSTER_NAME)

helm repo add hashicorp https://helm.releases.hashicorp.com \
    && helm repo update

cat > values.yaml << EOF
injector:
   enabled: true
   externalVaultAddr: "$VAULT_ADDR"
EOF

cat values.yaml

helm install vault -f values.yaml hashicorp/vault
sleep 10
while ! kubectl get pods -l app.kubernetes.io/name=vault-agent-injector | grep 1/1 2>/dev/null; do
    sleep 3
  done

kubectl create clusterrolebinding oidc-reviewer \
--clusterrole=system:service-account-issuer-discovery \
--group=system:unauthenticated


ISSUER="$(kubectl get --raw /.well-known/openid-configuration | jq -r '.issuer')" && echo $ISSUER

vault auth enable jwt
vault write auth/jwt/config oidc_discovery_url="${ISSUER}"

vault policy write exampleapp-read - << EOF
path "secret/data/exampleapp/config" {
  capabilities = ["read"]
}
path "pki_int/*" {
  capabilities = [ "create", "read", "update", "delete", "list", "sudo" ]
}
EOF


vault write auth/jwt/role/vault-jwt-product \
    role_type="jwt" \
    bound_audiences="${ISSUER}" \
    user_claim="sub" \
    bound_subject="system:serviceaccount:default:default" \
    policies="exampleapp-read" \
    ttl="1h"

sleep 5

kubectl apply -f - <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-deployment
  labels:
    app: web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/agent-init-first: "true"
        vault.hashicorp.com/namespace: "admin"
        vault.hashicorp.com/role: "vault-jwt-product"
        vault.hashicorp.com/auth-path: "auth/jwt"
        vault.hashicorp.com/agent-inject-secret-index.html: "pki_int/issue/example-dot-com"
        vault.hashicorp.com/agent-inject-template-index.html: |
          {{- with pkiCert "pki_int/issue/example-dot-com" "common_name=test.example.com" "ttl=2h" -}}
          {{ .Cert }}{{ .CA }}{{ .Key }}
          {{ .Key | writeToFile "/vault/secrets/cert.key" "vault" "vault" "0644" }}
          {{ .CA | writeToFile "/vault/secrets/cert.pem" "vault" "vault" "0644" }}
          {{ .Cert | writeToFile "/vault/secrets/cert.pem" "vault" "vault" "0644" "append" }}
          {{- end -}}
    spec:
      containers:
        - name: web
          image: nginx
---
EOF

sleep 5

kubectl logs \
      $(kubectl get pod -l app=web -o jsonpath="{.items[0].metadata.name}") \
      --all-containers=true

sleep 5

kubectl exec \
      $(kubectl get pod -l app=web -o jsonpath="{.items[0].metadata.name}") \
      -- cat /vault/secrets/index.html

# kubectl scale --replicas=2 deployments/web-deployment
