data "tfe_outputs" "gke" {
  organization = "emea-se-playground-2019"
  workspace = "gke-cluster-infra"
}

provider "helm" {
  kubernetes {
    host     = data.tfe_outputs.gke.values.kubernetes_cluster_endpoint

    client_certificate     = data.tfe_outputs.gke.values.kubernetes_cluster_certificate
    client_key             = data.tfe_outputs.gke.values.kubernetes_cluster_key
    cluster_ca_certificate = data.tfe_outputs.gke.values.kubernetes_cluster_ca
  }
}