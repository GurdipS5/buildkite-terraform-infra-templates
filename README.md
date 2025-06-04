🏗️ Terraform Infrastructure Pipelines

    Secure, scalable infrastructure-as-code pipelines with automated deployment across multiple environments

📋 Table of Contents

    🎯 Overview
    🏗️ Architecture
    🚀 Features
    📦 Prerequisites
    ⚙️ Setup
    🔧 Configuration
    🛡️ Security
    🚦 Pipeline Stages
    📁 Repository Structure
    🔐 Secrets Management
    📊 Monitoring
    🤝 Contributing
    📚 Documentation

🎯 Overview

This repository contains enterprise-grade Terraform/OpenTofu infrastructure pipelines designed for secure, automated deployment across development, staging, and production environments. Built with Windows agents and integrated with HashiCorp Vault for secrets management.
Key Technologies

Technology	Purpose	Version
🔧 OpenTofu	Infrastructure as Code	Latest
🏗️ Buildkite	CI/CD Pipeline	Latest
🔐 HashiCorp Vault	Secrets Management	v1.15+
💾 MinIO	State Backend Storage	Latest
🖥️ Windows	Build Agents	Server 2019+
⚡ PowerShell	Automation Scripts	7.0+

🏗️ Architecture

mermaid

graph TB
    A[👤 Developer] --> B[📝 Git Repository]
    B --> C[🏗️ Buildkite Pipeline]
    C --> D{🔍 Security Scan}
    D --> E{✅ Format Check}
    E --> F{🧪 Validation}
    F --> G[🌱 Development]
    G --> H[🧪 Staging]
    H --> I[🚀 Production]
    
    C --> J[🔐 HashiCorp Vault]
    J --> K[🗄️ MinIO Backend]
    
    style A fill:#e1f5fe
    style G fill:#e8f5e8
    style H fill:#fff3e0
    style I fill:#ffebee

🚀 Features

    ✅ Automated Security Scanning - Integrated security tools via PowerShell scripts
    🎨 Code Formatting Validation - Automatic Terraform formatting checks
    🔐 Vault Integration - Secure secrets management with OIDC authentication
    💾 MinIO Backend - S3-compatible state storage with encryption
    🌍 Multi-Environment - Automated progression through dev → staging → production
    🛡️ Approval Gates - Manual approval required for production deployments
    📊 Artifact Management - Plan files and outputs stored securely
    🖥️ Windows Native - Optimized for Windows build agents
    🔄 State Management - Secure remote state with locking
    📈 Monitoring - Built-in logging and artifact tracking

📦 Prerequisites
🖥️ Windows Build Agents

Ensure your Buildkite Windows agents have the following installed:

    OpenTofu CLI (tofu) - Download
    HashiCorp Vault CLI (vault) - Download
    PowerShell 7.0+ - Download
    Buildkite Agent - Setup Guide

🔐 Vault Configuration

Configure Vault with JWT authentication for Buildkite:

bash

# Enable JWT auth method
vault auth enable jwt

# Configure JWT authentication
vault write auth/jwt/config \
    bound_issuer="https://agent.buildkite.com" \
    jwks_url="https://agent.buildkite.com/.well-known/jwks"

# Create role for Buildkite
vault write auth/jwt/role/buildkite-terraform \
    bound_audiences="https://buildkite.com/{your-org}" \
    bound_claims=org_slug="your-buildkite-org" \
    user_claim="sub" \
    role_type="jwt" \
    policies="terraform-policy" \
    ttl=1h

⚙️ Setup
1. 📂 Clone Repository

bash

git clone https://github.com/your-org/terraform-pipelines.git
cd terraform-pipelines

2. 🏗️ Create Buildkite Pipeline

    Navigate to Buildkite dashboard
    Create new pipeline
    Set repository URL
    Set pipeline file path: .buildkite/pipeline.yml
    Configure Windows agent queue

3. 🔐 Configure Vault Secrets

Store your secrets in Vault:

bash

# MinIO credentials
vault kv put secret/minio/terraform \
    access_key="your-minio-access-key" \
    secret_key="your-minio-secret-key"

# Environment-specific secrets
vault kv put secret/terraform/dev \
    db_password="dev-db-password" \
    api_key="dev-api-key"

vault kv put secret/terraform/staging \
    db_password="staging-db-password" \
    api_key="staging-api-key"

vault kv put secret/terraform/production \
    db_password="production-db-password" \
    api_key="production-api-key"

🔧 Configuration
📄 Backend Configuration

Your backend.tf should look like this:

hcl

terraform {
  backend "s3" {
    endpoint                    = "https://minio.example.com"
    bucket                      = "terraform-state"
    key                         = "myproject/terraform.tfstate"
    region                      = "us-east-1"
    
    force_path_style            = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    
    # Credentials provided via environment variables:
    # AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
  }
}

🔧 Environment Variables

Update the pipeline with your specific values:

yaml

env:
  VAULT_ADDR: "https://your-vault.example.com"
  TF_WORKSPACE: "development"  # or staging/production

🛡️ Security
🔐 Secrets Management

    No hardcoded secrets in repository
    Vault OIDC integration for authentication
    Short-lived tokens with automatic rotation
    Least-privilege access policies
    Audit logging for all secret access

🛡️ Security Scanning

Custom PowerShell security scanning script at scripts/security-scan.ps1:

powershell

# Example security tools integration
& tfsec .
& checkov -d .
& terrascan scan

🚦 Pipeline Stages
🔍 Build Phase

    🎨 Code Formatting - Validates Terraform formatting
    🛡️ Security Scanning - Runs security analysis tools
    ✅ Validation - Terraform validation and planning

🚀 Deployment Phase

    🌱 Development - Automatic deployment to dev environment
    🧪 Staging - Manual approval required
    🚀 Production - Additional approval with reason required

📁 Repository Structure

terraform-pipelines/
├── 📁 .buildkite/
│   ├── 📄 pipeline.yml          # Main pipeline configuration
│   └── 📁 hooks/               # Optional pipeline hooks
├── 📁 environments/
│   ├── 📄 dev.tfvars           # Development variables
│   ├── 📄 staging.tfvars       # Staging variables
│   └── 📄 production.tfvars    # Production variables
├── 📁 modules/
│   ├── 📁 networking/          # Custom Terraform modules
│   ├── 📁 compute/
│   └── 📁 storage/
├── 📁 scripts/
│   ├── 📄 security-scan.ps1    # Security scanning script
│   └── 📄 deploy-helpers.ps1   # Deployment utilities
├── 📄 backend.tf               # Backend configuration
├── 📄 main.tf                  # Main Terraform configuration
├── 📄 variables.tf             # Variable definitions
├── 📄 outputs.tf               # Output definitions
├── 📄 versions.tf              # Provider version constraints
└── 📄 README.md               # This file

🔐 Secrets Management
Required Vault Secrets

Path	Fields	Description
secret/minio/terraform	access_key, secret_key	MinIO credentials for state backend
secret/terraform/dev	db_password, api_key	Development environment secrets
secret/terraform/staging	db_password, api_key	Staging environment secrets
secret/terraform/production	db_password, api_key	Production environment secrets

Vault Policies

hcl

# terraform-policy.hcl
path "secret/data/minio/terraform" {
  capabilities = ["read"]
}

path "secret/data/terraform/*" {
  capabilities = ["read"]
}

📊 Monitoring
📈 Pipeline Metrics

    Build Success Rate - Track deployment success across environments
    Security Scan Results - Monitor security findings and trends
    Deployment Duration - Measure pipeline performance
    State Lock Status - Monitor state file locking

🔍 Artifacts

The pipeline generates the following artifacts:

    📋 Security Reports - security-reports/**/*
    📄 Terraform Plans - *.tfplan
    📊 Environment Outputs - *-outputs.json

🤝 Contributing
🔄 Development Workflow

    🌿 Create Feature Branch

    bash

    git checkout -b feature/new-infrastructure

    ✏️ Make Changes
        Update Terraform configurations
        Modify pipeline as needed
        Update documentation
    🧪 Test Locally

    bash

    tofu fmt -check
    tofu validate
    tofu plan

    📤 Submit Pull Request
        Pipeline will automatically run validation
        Security scans must pass
        Peer review required

📋 Code Standards

    🎨 Formatting - All Terraform files must be formatted (tofu fmt)
    📝 Documentation - Document all variables and outputs
    🔐 Security - No secrets in code, security scans must pass
    🧪 Testing - Changes must pass validation and planning

📚 Documentation
📖 Additional Resources

    📘 OpenTofu Documentation
    🏗️ Buildkite Documentation
    🔐 HashiCorp Vault Documentation
    💾 MinIO Documentation

🆘 Troubleshooting
Common Issues

🔴 Vault Authentication Failed

bash

# Check OIDC token and role configuration
vault auth -method=jwt role=buildkite-terraform jwt=$BUILDKITE_OIDC_TOKEN

🔴 MinIO Connection Issues

bash

# Verify MinIO credentials and endpoint
aws --endpoint-url=https://minio.example.com s3 ls

🔴 State Lock Issues

bash

# Force unlock if needed (use with caution)
tofu force-unlock <lock-id>

📞 Support

For questions or issues:

    📧 Email: infrastructure-team@company.com
    💬 Slack: #infrastructure-help
    🎫 Jira: Create ticket in INFRA project

<div align="center">

🚀 Built with ❤️ by the Infrastructure Team

</div>
