variable "namespaces" {
  type    = list(string)
  default = ["cluster-1", "cluster-2"]
}
variable "project" {
  description = "project"
}
variable "region" {
  description = "region"
  default     = "europe-west2"
}


# =================================================================
# Optional

variable "gke_username" {
  default     = ""
  description = "gke username"
}

variable "gke_password" {
  default     = ""
  description = "gke password"
}

variable "gke_num_nodes" {
  default     = 3
  description = "number of gke nodes"
}
