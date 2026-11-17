# 🚄 Railway Asset Maintenance System

[![Terraform](https://img.shields.io/badge/Terraform-1.7+-7B42BC?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Azure](https://img.shields.io/badge/Azure-Cloud-0078D4?logo=microsoftazure&logoColor=white)](https://azure.microsoft.com/)
[![Linux](https://img.shields.io/badge/OS-Linux-FCC624?logo=linux&logoColor=black)](https://www.linux.org/)
[![Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF?logo=githubactions&logoColor=white)](https://github.com/features/actions)

An end-to-end, beginner-friendly DevOps portfolio project showcasing **Infrastructure as Code (IaC)** with **Terraform on Azure**, **Linux Bash automation**, and **Continuous Integration (CI)** with **GitHub Actions** for an intelligent Railway IoT Asset Maintenance System.

---

## 📋 Table of Contents
- [Project Overview](#-project-overview)
- [Repository Structure](#-repository-structure)
- [Architecture & Tech Stack](#-architecture--tech-stack)
- [Prerequisites](#-prerequisites)
- [Quick Start Guide](#-quick-start-guide)
  - [1. Explore Sample Sensor Data](#1-explore-sample-sensor-data)
  - [2. Run the System Monitor Script (Bash/Linux)](#2-run-the-system-monitor-script-bashlinux)
  - [3. Format and Validate Terraform Code](#3-format-and-validate-terraform-code)
  - [4. Inspect the CI Pipeline](#4-inspect-the-ci-pipeline)
- [Terraform Infrastructure Details](#-terraform-infrastructure-details)
- [Safety & Cost Guardrails](#-safety--cost-guardrails)
- [Documentation](#-documentation)

---

## 🎯 Project Overview

Modern railway networks utilize thousands of IoT sensors across track segments, wheel axle bearings, pantographs, and track switches to detect defects before failures occur.

This project delivers the supporting DevOps foundation:
1. **Infrastructure as Code**: Provisions an Azure Resource Group, Virtual Network, Subnet, Network Security Group, an Ubuntu Linux Edge Processing Node, and an Azure Blob Storage container for telemetry ingestion.
2. **Automated Monitoring**: A Bash shell script that monitors host resources (CPU, Memory, Disk) and evaluates railway sensor readings against safety thresholds.
3. **Continuous Integration**: A GitHub Actions workflow that automatically validates code formatting, Terraform syntax, and script health on every push or pull request without deploying live resources or incurring cloud costs.

---

## 📂 Repository Structure

```text
railway-asset-maintenance-system/
│
├── .github/
│   └── workflows/
│       └── terraform-validation.yml    # GitHub Actions CI workflow (linting & validation)
│
├── docs/
│   └── architecture.md                 # System architecture diagrams, data flow & security
│
├── sample-data/
│   └── railway-sensor-data.csv         # Realistic railway IoT sensor telemetry dataset
│
├── scripts/
│   └── system-monitor.sh               # Bash script for host metrics & telemetry diagnosis
│
├── terraform/
│   ├── main.tf                         # Core Azure infrastructure resources definition
│   ├── variables.tf                    # Input variables with types and validations
│   └── outputs.tf                      # Exported attributes (IPs, connection strings, keys)
│
├── .gitignore                          # Excludes Terraform state, secrets, and logs
└── README.md                           # Project documentation and guide
```

---

## 🛠️ Architecture & Tech Stack

| Technology | Purpose | Key File |
| :--- | :--- | :--- |
| **Microsoft Azure** | Target cloud provider for virtual networking, compute, and blob storage | `terraform/main.tf` |
| **Terraform (HCL)** | Infrastructure as Code provisioning tool | `terraform/*.tf` |
| **Linux (Ubuntu 22.04)** | Operating system for edge maintenance node | `terraform/main.tf` |
| **Bash** | Automation scripting language for health checks and data parsing | `scripts/system-monitor.sh` |
| **GitHub Actions** | Automated CI quality pipeline | `.github/workflows/terraform-validation.yml` |

For detailed diagrams and component breakdowns, see [docs/architecture.md](docs/architecture.md).

---

## ⚙️ Prerequisites

To run and inspect this project locally, you only need standard open-source developer tools:

- **Terraform CLI** (v1.3.0 or higher) - [Download Terraform](https://developer.hashicorp.com/terraform/install)
- **Bash Shell** (Linux, macOS, WSL on Windows, or Git Bash)
- **Git** - [Download Git](https://git-scm.com/)
- *(Optional)* **Azure CLI** - Only if you choose to deploy live resources in the future.

---

## 🚀 Quick Start Guide

### 1. Explore Sample Sensor Data
The `sample-data/railway-sensor-data.csv` file contains real-world railway telemetry:
```bash
# View the first few rows of sensor readings
head -n 5 sample-data/railway-sensor-data.csv
```
Telemetry includes asset identifiers (`AXL-TRAIN-12002`), temperatures, vibration RMS values, and operational statuses (`Normal`, `Warning`, `Critical`).

---

### 2. Run the System Monitor Script (Bash/Linux)
The script `scripts/system-monitor.sh` monitors edge host resources and parses sensor telemetry.

```bash
# 1. Grant execute permissions
chmod +x scripts/system-monitor.sh

# 2. View available options
./scripts/system-monitor.sh --help

# 3. Run sensor telemetry analysis
./scripts/system-monitor.sh --sensors

# 4. Run full diagnostic (System health + sensor analysis)
./scripts/system-monitor.sh --all
```

**Sample Output:**
```text
==================================================================
   RAILWAY ASSET MAINTENANCE SYSTEM - HEALTH & TELEMETRY MONITOR  
==================================================================
>>> 1. Checking Edge Host System Resources...
 - CPU Load (1m, 5m, 15m)       : 0.12, 0.08, 0.05
 - Memory Utilization           : 1420MB / 7850MB (18%)
 - Primary Disk Partition Usage : 32% used (38G/124G on /)

>>> 2. Analyzing Railway IoT Sensor Telemetry...
 Data Source        : sample-data/railway-sensor-data.csv
 Total Assets Monitored : 14
 [STATUS] Normal    : 8
 [STATUS] Warning   : 4
 [STATUS] Critical  : 2
```

---

### 3. Format and Validate Terraform Code
You can validate the Terraform configuration **locally without any cloud credentials**:

```bash
# Navigate to the terraform directory
cd terraform

# Step A: Check canonical formatting (should return clean)
terraform fmt -check

# Step B: Initialize providers locally (offline mode)
terraform init -backend=false

# Step C: Validate syntax and argument references
terraform validate
```

Expected validation result:
```text
Success! The configuration is valid.
```

---

### 4. Inspect the CI Pipeline
The GitHub Actions workflow at `.github/workflows/terraform-validation.yml` runs two automated jobs:
1. **`terraform-validation`**: Checks formatting (`terraform fmt`), runs offline provider initialization, and validates syntax (`terraform validate`).
2. **`bash-validation`**: Verifies shell syntax using `bash -n` and performs a non-destructive dry-run of `./scripts/system-monitor.sh --sensors`.

---

## 🛡️ Safety & Cost Guardrails

> [!IMPORTANT]
> **Zero Cloud Cost Guarantee:**
> - This project is designed for portfolio demonstration, learning, and automated CI validation.
> - **No resources are deployed to Azure** during local testing or GitHub Actions validation.
> - Do not run `terraform apply` unless you intentionally intend to provision cloud resources on your personal Azure subscription.

---

## 📚 Documentation

- [System Architecture & Design Document](docs/architecture.md)
- [Input Variables Reference](terraform/variables.tf)
- [Exported Outputs Reference](terraform/outputs.tf)
