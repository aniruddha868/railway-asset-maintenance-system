# ==============================================================================
# File        : outputs.tf
# Description : Output values exported by Terraform after planning or applying.
# Purpose     : Exposes important metadata (IP addresses, resource names, connection
#               commands) for use by downstream CI/CD pipelines, scripts, or operators.
# ==============================================================================

# ------------------------------------------------------------------------------
# Resource Group & Storage Outputs
# ------------------------------------------------------------------------------

output "resource_group_name" {
  description = "The name of the provisioned Azure Resource Group."
  value       = azurerm_resource_group.railway_rg.name
}

output "storage_account_name" {
  description = "The globally unique name of the Azure Storage Account used for telemetry data."
  value       = azurerm_storage_account.telemetry_sa.name
}

output "storage_container_name" {
  description = "The name of the Blob Storage Container storing incoming sensor data."
  value       = azurerm_storage_container.telemetry_container.name
}

# ------------------------------------------------------------------------------
# Networking Outputs
# ------------------------------------------------------------------------------

output "virtual_network_name" {
  description = "The name of the Virtual Network hosting edge maintenance components."
  value       = azurerm_virtual_network.railway_vnet.name
}

output "subnet_id" {
  description = "The Resource ID of the edge computing subnet."
  value       = azurerm_subnet.edge_subnet.id
}

# ------------------------------------------------------------------------------
# Compute & Connectivity Outputs
# ------------------------------------------------------------------------------

output "vm_name" {
  description = "The hostname and resource name of the Linux edge maintenance virtual machine."
  value       = azurerm_linux_virtual_machine.edge_vm.name
}

output "vm_public_ip" {
  description = "The static public IPv4 address assigned to the edge VM."
  value       = azurerm_public_ip.edge_pip.ip_address
}

output "vm_private_ip" {
  description = "The private IP address of the edge VM within the virtual network."
  value       = azurerm_network_interface.edge_nic.private_ip_address
}

output "ssh_connection_command" {
  description = "Convenient CLI command to connect to the edge processing server once provisioned."
  value       = "ssh -i id_rsa ${var.admin_username}@${azurerm_public_ip.edge_pip.ip_address}"
}

# ------------------------------------------------------------------------------
# Security Note on Sensitive Outputs
# ------------------------------------------------------------------------------
# Marking 'sensitive = true' prevents Terraform from printing the private key in
# plain text on the terminal screen during 'terraform apply' or in CI/CD build logs.
output "ssh_private_key_pem" {
  description = "The generated RSA 4096-bit private key. Marked sensitive to prevent log leaks."
  value       = tls_private_key.edge_ssh_key.private_key_pem
  sensitive   = true
}
