
# test script to destroy (most)steps and k8s yaml files

gcloud container clusters get-credentials \
  $(terraform output -json kubernetes_clusters | jq -r ".[0].kubernetes_cluster_name")  \
    --region $(terraform output -json region | jq -r)
kubectl delete VaultStaticSecret vault-static-secret
kubectl delete VaultPKISecret vault-pki 
kubectl delete VaultConnection vault-connection 
kubectl delete VaultAuth vault-auth 

kubectl delete ClusterRoleBinding role-tokenreview-binding
kubectl delete sa vault-auth
helm uninstall vault-secrets-operator --namespace vault-secrets-operator
gcloud container clusters get-credentials \
  $(terraform output -json kubernetes_clusters | jq -r ".[1].kubernetes_cluster_name")  \
    --region $(terraform output -json region | jq -r)
helm uninstall vault
kubectl delete deployment web-deployment
kubectl delete clusterrolebinding oidc-reviewer
vault auth disable cluster1
vault auth disable jwt
rm ~/.kube/config
rm cluster1_ca.crt
rm values.yaml
