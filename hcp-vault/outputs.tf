output "hcp_vault_root_token" {
  value = hcp_vault_cluster_admin_token.root.token
  sensitive = true
}