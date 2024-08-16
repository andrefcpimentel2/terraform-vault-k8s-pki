output "vault_pki_secret_backend_root_cert_root_2023" {
  value = vault_pki_secret_backend_root_cert.root_2023.certificate
}

output "vault_pki_secret_backend_cert_example-dot-com_cert" {
  value = vault_pki_secret_backend_cert.example-dot-com.certificate
}

output "vault_pki_secret_backend_cert_example-dot-com_issuring_ca" {
  value = vault_pki_secret_backend_cert.example-dot-com.issuing_ca
}

output "vault_pki_secret_backend_cert_example-dot-com_serial_number" {
  value = vault_pki_secret_backend_cert.example-dot-com.serial_number
#   sensitive = true
}

output "vault_pki_secret_backend_cert_example-dot-com_private_key_type" {
  value = vault_pki_secret_backend_cert.example-dot-com.private_key_type
}