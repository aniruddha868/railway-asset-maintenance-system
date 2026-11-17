# ==============================================================================
# File        : main.tf
# Description : Primary Terraform configuration for Railway Asset Maintenance System.
# Cloud       : Microsoft Azure
# Resources   :
#   - Resource Group (Logical container for project resources)
#   - Storage Account & Blob Container (For railway sensor telemetry ingestion)
#   - Virtual Network & Subnet (Isolated private network for monitoring systems)
#   - Network Security Group (Firewall rules controlling traffic)
#   - Public IP & Network Interface (Edge gateway network connectivity)
#   - TLS Private Key (Auto-generated secure SSH key for edge node access)
#   - Linux Virtual Machine (Edge processing server running diagnostic scripts)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Terraform Settings & Required Providers Block
# ------------------------------------------------------------------------------
# Declares the required Terraform version and provider plugins downloaded during
# 'terraform init'. Pinning versions avoids breaking changes in automated CI/CD.
terraform {
  required_version = ">= 1.3.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.0"
    }
  }
}

# ------------------------------------------------------------------------------
# 2. Azure Provider Configuration
# ------------------------------------------------------------------------------
# The Azure Resource Manager provider enables managing Azure resources.
# 'features {}' is required by the AzureRM provider to configure provider behavior.
provider "azurerm" {
  features {}
}

# ------------------------------------------------------------------------------
# 3. Random String Generator (for unique resource naming)
# ------------------------------------------------------------------------------
# Azure Storage Account names must be globally unique across all of Azure,
# lowercase, and between 3 to 24 characters without hyphens.
resource "random_string" "unique_suffix" {
  length  = 6
  special = false
  upper   = false
}

# ------------------------------------------------------------------------------
# 4. Azure Resource Group
# ------------------------------------------------------------------------------
# A Resource Group is a logical container into which Azure resources are deployed
# and managed. Deleting the group removes all child resources cleanly.
resource "azurerm_resource_group" "railway_rg" {
  name     = "${var.project_name}-${var.environment}-rg"
  location = var.azure_region
  tags     = var.common_tags
}

# ------------------------------------------------------------------------------
# 5. Azure Storage Account (IoT Telemetry & Log Ingestion)
# ------------------------------------------------------------------------------
# Stores high-volume telemetry data collected from train sensors (bogies, track,
# pantographs, temperature, vibrations). Standard_LRS provides cost-effective
# locally redundant storage within a single region.
resource "azurerm_storage_account" "telemetry_sa" {
  name                     = "sa${replace(var.project_name, "-", "")}${var.environment}${random_string.unique_suffix.result}"
  resource_group_name      = azurerm_resource_group.railway_rg.name
  location                 = azurerm_resource_group.railway_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # Enforce TLS 1.2 minimum for data-in-transit security
  min_tls_version = "TLS1_2"

  tags = var.common_tags
}

# Blob Storage Container for storing incoming raw CSV sensor logs
resource "azurerm_storage_container" "telemetry_container" {
  name                  = "sensor-telemetry-data"
  storage_account_name  = azurerm_storage_account.telemetry_sa.name
  container_access_type = "private" # Restrict public access for safety
}

# ------------------------------------------------------------------------------
# 6. Networking Infrastructure (VNet, Subnet, NSG)
# ------------------------------------------------------------------------------

# Virtual Network provides an isolated private cloud network for monitoring systems
resource "azurerm_virtual_network" "railway_vnet" {
  name                = "${var.project_name}-${var.environment}-vnet"
  resource_group_name = azurerm_resource_group.railway_rg.name
  location            = azurerm_resource_group.railway_rg.location
  address_space       = var.vnet_address_space
  tags                = var.common_tags
}

# Dedicated Subnet for the edge telemetry processing virtual machines
resource "azurerm_subnet" "edge_subnet" {
  name                 = "edge-processing-subnet"
  resource_group_name  = azurerm_resource_group.railway_rg.name
  virtual_network_name = azurerm_virtual_network.railway_vnet.name
  address_prefixes     = var.subnet_address_prefix
}

# Network Security Group (NSG) acts as a virtual firewall for inbound and outbound traffic
resource "azurerm_network_security_group" "edge_nsg" {
  name                = "${var.project_name}-${var.environment}-nsg"
  resource_group_name = azurerm_resource_group.railway_rg.name
  location            = azurerm_resource_group.railway_rg.location

  # Security Rule 1: Allow inbound SSH management (Port 22)
  # NOTE: In production environments, restrict 'source_address_prefix' to your specific office/VPN IP.
  security_rule {
    name                       = "Allow-SSH-Inbound"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Security Rule 2: Allow inbound HTTP dashboard/API metrics (Port 8080)
  security_rule {
    name                       = "Allow-HTTP-Dashboard-Inbound"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.common_tags
}

# Associate Network Security Group with the edge subnet
resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.edge_subnet.id
  network_security_group_id = azurerm_network_security_group.edge_nsg.id
}

# ------------------------------------------------------------------------------
# 7. Network Interface & Public IP for Edge Gateway Server
# ------------------------------------------------------------------------------

# Static Public IP to reach the edge telemetry monitoring node
resource "azurerm_public_ip" "edge_pip" {
  name                = "${var.project_name}-${var.environment}-pip"
  resource_group_name = azurerm_resource_group.railway_rg.name
  location            = azurerm_resource_group.railway_rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.common_tags
}

# Virtual Network Interface (NIC) bridging the VM to the subnet and public IP
resource "azurerm_network_interface" "edge_nic" {
  name                = "${var.project_name}-${var.environment}-nic"
  resource_group_name = azurerm_resource_group.railway_rg.name
  location            = azurerm_resource_group.railway_rg.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.edge_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.edge_pip.id
  }

  tags = var.common_tags
}

# ------------------------------------------------------------------------------
# 8. Cryptographic SSH Key Pair
# ------------------------------------------------------------------------------
# Generates a fresh RSA 4096-bit key pair inside Terraform state.
# This avoids hardcoding passwords or requiring manual local key generation.
resource "tls_private_key" "edge_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ------------------------------------------------------------------------------
# 9. Linux Virtual Machine (Edge Maintenance & Telemetry Ingestion Node)
# ------------------------------------------------------------------------------
# Represents an edge computing node installed in railway control cabins or
# central depots running real-time diagnostic checks and batch processing scripts.
resource "azurerm_linux_virtual_machine" "edge_vm" {
  name                  = "${var.project_name}-${var.environment}-vm"
  resource_group_name   = azurerm_resource_group.railway_rg.name
  location              = azurerm_resource_group.railway_rg.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.edge_nic.id]

  # SSH Key Authentication configuration
  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.edge_ssh_key.public_key_openssh
  }

  # OS Disk configuration
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  # Base Image: Ubuntu 22.04 LTS (Long Term Support)
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Optional Cloud-Init user data to bootstrap edge dependencies on first boot
  custom_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y curl wget unzip jq
    mkdir -p /opt/railway-maintenance/telemetry
    echo "Railway Edge Maintenance Node successfully initialized on $(date)" > /opt/railway-maintenance/node-status.txt
  EOF
  )

  tags = var.common_tags
}
