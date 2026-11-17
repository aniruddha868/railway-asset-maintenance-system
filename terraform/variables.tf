# ==============================================================================
# File        : variables.tf
# Description : Input variable definitions for the Railway Asset Maintenance System.
# Purpose     : Allows customizing resource names, cloud region, network ranges,
#               and sizing without modifying the core infrastructure code (main.tf).
# ==============================================================================

# ------------------------------------------------------------------------------
# Project & Environment Identifiers
# ------------------------------------------------------------------------------

variable "project_name" {
  description = "A short prefix used in naming all Azure resources for the Railway Asset Maintenance System."
  type        = string
  default     = "railway-maint"

  validation {
    condition     = length(var.project_name) > 2 && length(var.project_name) <= 18
    error_message = "The project_name must be between 3 and 18 characters long."
  }
}

variable "environment" {
  description = "Deployment target environment (dev, staging, or prod). Controls tags and resource sizing."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "The environment variable must be one of: dev, staging, prod."
  }
}

variable "azure_region" {
  description = "The Azure geographical region where resources will be provisioned."
  type        = string
  default     = "centralindia"
}

# ------------------------------------------------------------------------------
# Networking Configuration
# ------------------------------------------------------------------------------

variable "vnet_address_space" {
  description = "The IPv4 address space allocated to the Virtual Network (VNet)."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_address_prefix" {
  description = "The IPv4 address subnet prefix for the edge monitoring server."
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

# ------------------------------------------------------------------------------
# Compute (Linux Edge Monitoring Node) Configuration
# ------------------------------------------------------------------------------

variable "vm_size" {
  description = "The compute size (SKU) for the Linux edge processing virtual machine."
  type        = string
  default     = "Standard_B1s" # Economical, beginner-friendly 1 vCPU / 1 GiB RAM VM
}

variable "admin_username" {
  description = "Administrator username for logging into the Linux virtual machine via SSH."
  type        = string
  default     = "azureuser"
}

# ------------------------------------------------------------------------------
# Resource Tagging
# ------------------------------------------------------------------------------

variable "common_tags" {
  description = "A standard map of resource tags applied to every cloud asset for cost tracking and governance."
  type        = map(string)
  default = {
    Project     = "Railway-Asset-Maintenance-System"
    ManagedBy   = "Terraform"
    Environment = "Dev"
    Owner       = "DevOps-Team"
  }
}
