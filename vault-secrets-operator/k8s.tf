resource "kubernetes_service_account" "vault" {
  metadata {
    name = "vault-auth"
  }
}

resource "kubernetes_cluster_role_binding" "example" {
  metadata {
    name = "vault-auth"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:auth-delegator"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.vault.metadata.0.name
    api_group = "rbac.authorization.k8s.io"
    namespace =  "default"
  }

}

resource "kubernetes_secret" "example" {
  metadata {
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.vault.metadata.0.name
    }

    generate_name = "vault-auth-"
  }

  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}