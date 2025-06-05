# scripts/scan-secrets.ps1
# GitGuardian secret scanning for the current commit/build

param(
    [string]$OutputPath = "gitguardian-results.json",
    [string]$ConfigPath = ".gitguardian.yml",
    [switch]$FailOnSecrets = $true,
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Stop"

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Cyan
    Write-Host ""
}

function Install-GitGuardian {
    Write-Host "📦 Installing GitGuardian CLI..."
    
    try {
        # Check if ggshield is already installed
        $version = ggshield --version 2>$null
        if ($version) {
            Write-Host "✅ GitGuardian CLI already installed: $version"
            return
        }
    } catch {
        # Not installed, proceed with installation
    }
    
    # Install via pip
    Write-Host "Installing GitGuardian CLI via pip..."
    pip install --upgrade ggshield
    
    # Verify installation
    $version = ggshield --version
    Write-Host "✅ GitGuardian CLI installed: $version"
}

function Get-GitGuardianApiKey {
    Write-Host "🔐 Checking GitGuardian API key..."
    
    if (-not $env:GITGUARDIAN_API_KEY) {
        Write-Host "⚠️ GITGUARDIAN_API_KEY environment variable not set"
        
        # Try to get from Vault if available
        try {
            if (Get-Command vault -ErrorAction SilentlyContinue) {
                Write-Host "Attempting to retrieve from Vault..."
                $env:GITGUARDIAN_API_KEY = vault kv get -field=api_key secret/gitguardian/api
                Write-Host "✅ GitGuardian API key retrieved from Vault"
            } else {
                Write-Error "❌ GitGuardian API key not found and Vault not available"
            }
        } catch {
            Write-Error "❌ Could not retrieve GitGuardian API key from Vault: $($_.Exception.Message)"
        }
    } else {
        Write-Host "✅ GitGuardian API key found in environment"
    }
    
    # Test API connectivity
    try {
        $quotaInfo = ggshield quota --json 2>$null | ConvertFrom-Json
        Write-Host "✅ API connectivity verified - Quota: $($quotaInfo.count)/$($quotaInfo.limit)"
    } catch {
        Write-Warning "⚠️ Could not verify API connectivity"
    }
}

function Get-CurrentCommit {
    Write-Host "📝 Getting current commit information..."
    
    $currentCommit = git rev-parse HEAD
    $currentCommitShort = git rev-parse --short HEAD
    $commitMessage = git log -1 --pretty=format:"%s"
    $commitAuthor = git log -1 --pretty=format:"%an"
    $commitDate = git log -1 --pretty=format:"%ci"
    
    Write-Host "   Commit: $currentCommitShort"
    Write-Host "   Message: $commitMessage"
    Write-Host "   Author: $commitAuthor"
    Write-Host "   Date: $commitDate"
    
    return @{
        hash = $currentCommit
        short_hash = $currentCommitShort
        message = $commitMessage
        author = $commitAuthor
        date = $commitDate
    }
}

function Test-ConfigFile {
    if (Test-Path $ConfigPath) {
        Write-Host "✅ Using GitGuardian config: $ConfigPath"
        return $true
    } else {
        Write-Host "⚠️ GitGuardian config not found: $ConfigPath"
        Write-Host "Creating minimal configuration..."
        
        $defaultConfig = @"
# GitGuardian configuration for secret scanning
api_url: https://api.gitguardian.com

# Paths to scan
paths-scan:
  - "**/*.tf"
  - "**/*.tfvars"
  - "**/*.yml"
  - "**/*.yaml"
  - "**/*.json"
  - "**/*.ps1"
  - "**/*.sh"
  - "**/*.py"
  - "**/*.js"
  - "**/*.ts"

# Paths to ignore
paths-ignore:
  - "**/*.md"
  - "**/README*"
  - "**/.git/**"
  - "**/node_modules/**"
  - "**/vendor/**"
  - "**/.terraform/**"
  - "**/terraform.tfstate*"
  - "**/*.log"

# Scanning options
exit-zero: false
scan:
  show-secrets: false
  mode: pre-push
  verbose: false
  json: true

# Specific detectors
detectors:
  - name: "Terraform AWS Access Key"
    enabled: true
  - name: "HashiCorp Vault Token"
    enabled: true
  - name: "Docker Auth Token"
    enabled: true
  - name: "GitHub Token"
    enabled: true
  - name: "Generic High Entropy String"
    enabled: false
"@
        $defaultConfig | Out-File $ConfigPath -Encoding UTF8
        Write-Host "✅ Created default GitGuardian configuration"
        return $true
    }
}

function Invoke-SecretScan {
    param(
        [object]$CommitInfo,
        [string]$ConfigPath,
        [string]$OutputPath,
        [bool]$FailOnSecrets,
        [bool]$Verbose
    )
    
    Write-Host "🔍 Scanning for secrets in current commit..."
    
    # Ensure output directory exists
    $outputDir = Split-Path $OutputPath -Parent
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    # Build ggshield command
    $scanArgs = @(
        "secret", "scan", "commit", $CommitInfo.hash,
        "--json",
        "--output", $OutputPath
    )
    
    if (Test-Path $ConfigPath) {
        $scanArgs += @("--config", $ConfigPath)
    }
    
    if (-not $FailOnSecrets) {
        $scanArgs += "--exit-zero"
    }
    
    if ($Verbose) {
        $scanArgs += "--verbose"
    }
    
    Write-Host "Executing: ggshield $($scanArgs -join ' ')"
    
    try {
        # Run GitGuardian scan
        $result = & ggshield @scanArgs 2>&1
        $exitCode = $LASTEXITCODE
        
        Write-Host "GitGuardian scan completed with exit code: $exitCode"
        
        # Parse and display results
        if (Test-Path $OutputPath) {
            try {
                $scanResults = Get-Content $OutputPath | ConvertFrom-Json
                Display-ScanResults $scanResults $CommitInfo
            } catch {
                Write-Host "⚠️ Could not parse scan results: $($_.Exception.Message)"
                if ($result) {
                    Write-Host "Raw output:"
                    Write-Host $result
                }
            }
        }
        
        return $exitCode
        
    } catch {
        Write-Error "❌ GitGuardian scan failed: $($_.Exception.Message)"
    }
}

function Display-ScanResults {
    param(
        [object]$ScanResults,
        [object]$CommitInfo
    )
    
    Write-Host ""
    Write-Host "📊 GitGuardian Scan Results:" -ForegroundColor Yellow
    Write-Host "   Commit: $($CommitInfo.short_hash)"
    Write-Host "   Scan Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    
    if ($ScanResults.total_secrets -and $ScanResults.total_secrets -gt 0) {
        Write-Host "   🚨 Secrets Found: $($ScanResults.total_secrets)" -ForegroundColor Red
        Write-Host "   📋 Incidents: $($ScanResults.total_incidents)" -ForegroundColor Red
        
        # Display secret details (without exposing values)
        if ($ScanResults.secrets) {
            Write-Host ""
            Write-Host "🔍 Secret Details:" -ForegroundColor Red
            foreach ($secret in $ScanResults.secrets) {
                Write-Host "   ❌ Type: $($secret.type)" -ForegroundColor Red
                Write-Host "      File: $($secret.filename)" -ForegroundColor Red
                Write-Host "      Line: $($secret.line_start)" -ForegroundColor Red
                if ($secret.validity) {
                    Write-Host "      Validity: $($secret.validity)" -ForegroundColor Red
                }
                Write-Host ""
            }
        }
        
        Write-Host "🚨 ACTION REQUIRED: Secrets detected in commit $($CommitInfo.short_hash)" -ForegroundColor Red
        Write-Host "   1. Remove secrets from code" -ForegroundColor Yellow
        Write-Host "   2. Use environment variables or Vault" -ForegroundColor Yellow
        Write-Host "   3. Rewrite git history if secrets were committed" -ForegroundColor Yellow
        
    } else {
        Write-Host "   ✅ No secrets detected" -ForegroundColor Green
    }
}

function Generate-ScanSummary {
    param(
        [object]$CommitInfo,
        [string]$OutputPath,
        [int]$ExitCode
    )
    
    $summary = @{
        tool = "GitGuardian"
        scan_type = "commit"
        commit_hash = $CommitInfo.hash
        commit_short_hash = $CommitInfo.short_hash
        commit_message = $CommitInfo.message
        commit_author = $CommitInfo.author
        commit_date = $CommitInfo.date
        scan_timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        exit_code = $ExitCode
        scan_status = if ($ExitCode -eq 0) { "passed" } else { "failed" }
        output_file = $OutputPath
        build_info = @{
            buildkite_build_number = $env:BUILDKITE_BUILD_NUMBER
            buildkite_build_url = $env:BUILDKITE_BUILD_URL
            buildkite_branch = $env:BUILDKITE_BRANCH
            buildkite_commit = $env:BUILDKITE_COMMIT
        }
    }
    
    # Add scan results if available
    if (Test-Path $OutputPath) {
        try {
            $scanResults = Get-Content $OutputPath | ConvertFrom-Json
            $summary.secrets_found = if ($scanResults.total_secrets) { $scanResults.total_secrets } else { 0 }
            $summary.incidents_found = if ($scanResults.total_incidents) { $scanResults.total_incidents } else { 0 }
        } catch {
            $summary.secrets_found = "unknown"
            $summary.incidents_found = "unknown"
        }
    }
    
    $summaryPath = $OutputPath -replace "\.json$", "-summary.json"
    $summary | ConvertTo-Json -Depth 3 | Out-File $summaryPath -Encoding UTF8
    
    Write-Host "📋 Scan summary saved to: $summaryPath"
    return $summaryPath
}

# Main execution
Write-Header "GitGuardian Secret Scanning"

Write-Host "🔍 Scanning current commit for secrets..."
Write-Host "Output: $OutputPath"
Write-Host "Config: $ConfigPath"
Write-Host "Fail on secrets: $FailOnSecrets"

# Install GitGuardian CLI
Install-GitGuardian

# Get API key
Get-GitGuardianApiKey

# Get current commit info
$commitInfo = Get-CurrentCommit

# Test/create config file
Test-ConfigFile | Out-Null

# Run secret scan
$exitCode = Invoke-SecretScan -CommitInfo $commitInfo -ConfigPath $ConfigPath -OutputPath $OutputPath -FailOnSecrets $FailOnSecrets -Verbose $Verbose

# Generate summary
$summaryPath = Generate-ScanSummary -CommitInfo $commitInfo -OutputPath $OutputPath -ExitCode $exitCode

Write-Host ""
if ($exitCode -eq 0) {
    Write-Host "✅ GitGuardian scan completed successfully - no secrets detected" -ForegroundColor Green
} else {
    Write-Host "❌ GitGuardian scan failed - secrets detected!" -ForegroundColor Red
    
    if ($FailOnSecrets) {
        Write-Host "🛑 Build will fail due to detected secrets" -ForegroundColor Red
        exit $exitCode
    } else {
        Write-Host "⚠️ Continuing despite detected secrets (FailOnSecrets=false)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "📄 Generated files:"
Write-Host "   Results: $OutputPath"
Write-Host "   Summary: $summaryPath"
