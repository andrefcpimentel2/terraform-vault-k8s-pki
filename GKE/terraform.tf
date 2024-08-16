terraform {
  cloud {
    organization = "emea-se-playground-2019"
    hostname = "app.terraform.io" # Optional; defaults to app.terraform.io

    workspaces {
      project = "andre-kubernetes-pki"
      name    = "gke-cluster-infra"
    }
  }
}