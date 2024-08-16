module "gke" {
  count           = length(var.namespaces)
  source          = "./modules/cluster"
  namespace       = var.namespaces[count.index]
  project         = var.project
  region          = var.region
  network_name    = google_compute_network.vpc.name
  subnetwork_name = google_compute_subnetwork.subnet.name
}