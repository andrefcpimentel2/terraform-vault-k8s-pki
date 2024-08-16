locals {
  gcp_service_list = [
    "cloudkms.googleapis.com",
  ]
}
resource "google_project_service" "gcp_services" {
  for_each = toset(local.gcp_service_list)
  project = var.project
  service = each.key
}