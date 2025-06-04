# deploy.ps1
# Terraform Deployment Script
# Handles deployments for different environments

param (
    [string]$Environment
)

# Navigate to environment directory
Set-Location "environments\$Environment"

# Initialize Terraform working directory
terraform init

# Generate and save plan for review
terraform plan -out=tfplan
terraform show -json tfplan > "${Environment}-plan.txt"

# Apply the Terraform configuration
terraform apply tfplan
