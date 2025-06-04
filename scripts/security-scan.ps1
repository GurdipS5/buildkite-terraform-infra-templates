# security-scan.ps1
# Security & Quality Scan Script
# This script runs multiple security and quality tools on Terraform code

# Install required tools if not present
function Install-TerraformTools {
    param (
        [string]$ToolName,
        [string]$DownloadUrl,
        [string]$InstallPath
    )
    
    if (!(Get-Command $ToolName -ErrorAction SilentlyContinue)) {
        Write-Host "Installing $ToolName..."
        Invoke-WebRequest -Uri $DownloadUrl -OutFile "temp.tar.gz"
        tar -xzf "temp.tar.gz" -C $InstallPath
        Remove-Item "temp.tar.gz"
    }
}

# Install tools
$tools = @{
    "terrascan" = @{
        url = "https://github.com/accurics/terrascan/releases/download/v1.14.0/terrascan_1.14.0_windows_x64.tar.gz"
        path = "C:\tools"
    }
    "terralint" = @{
        url = "https://github.com/claranet/terralint/releases/download/v1.1.4/terralint_1.1.4_windows_x64.tar.gz"
        path = "C:\tools"
    }
    "tfsec" = @{
        url = "https://github.com/aquasecurity/tfsec/releases/download/v1.12.0/tfsec-windows-amd64.exe"
        path = "C:\tools"
    }
    "checkov" = @{
        url = "https://github.com/bridgecrewio/checkov/releases/download/2.3.0/checkov_2.3.0_windows.exe"
        path = "C:\tools"
    }
}

foreach ($tool in $tools.Keys) {
    Install-TerraformTools -ToolName $tool -DownloadUrl $tools[$tool].url -InstallPath $tools[$tool].path
}

# Run security scans
Write-Host "Running terrascan..."
terrascan scan -p . -o html > security-report.html

Write-Host "Running terralint..."
terralint .

Write-Host "Running tfsec..."
tfsec .

Write-Host "Running checkov..."
checkov -f json > checkov-report.json

# Exit with error if any scan fails
if ($LASTEXITCODE -ne 0) {
    Write-Host "Security scan failed. Please review the reports."
    exit 1
}
