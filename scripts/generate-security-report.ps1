# scripts/generate-security-report.ps1
# Generates HTML security report from aggregated security scan results

param(
    [string]$SecuritySummaryJson = "security-reports/security-summary.json",
    [string]$OutputPath = "security-reports/security-summary.html",
    [string]$ProjectName = $env:PROJECT_NAME,
    [string]$BuildUrl = $env:BUILDKITE_BUILD_URL
)

$ErrorActionPreference = "Stop"

function New-SecurityHtmlReport {
    param(
        [object]$SecurityData,
        [string]$ProjectName,
        [string]$BuildUrl
    )

    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Security Scan Report - $ProjectName</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
            margin: 0; 
            padding: 20px; 
            background-color: #f8f9fa; 
        }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
            color: white; 
            padding: 30px; 
            border-radius: 10px; 
            margin-bottom: 30px; 
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .header h1 { margin: 0; font-size: 2.5em; }
        .header p { margin: 5px 0; opacity: 0.9; }
        .summary-cards { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); 
            gap: 20px; 
            margin-bottom: 30px; 
        }
        .card { 
            background: white; 
            padding: 20px; 
            border-radius: 8px; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1); 
            text-align: center;
        }
        .card h3 { margin: 0 0 10px 0; color: #333; }
        .card .number { font-size: 2.5em; font-weight: bold; margin: 10px 0; }
        .critical { color: #dc3545; }
        .high { color: #fd7e14; }
        .medium { color: #ffc107; }
        .low { color: #28a745; }
        .info { color: #17a2b8; }
        .tools-section { 
            background: white; 
            padding: 25px; 
            border-radius: 8px; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1); 
            margin-bottom: 30px;
        }
        .tools-grid { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); 
            gap: 20px; 
        }
        .tool-card { 
            border: 1px solid #e9ecef; 
            padding: 15px; 
            border-radius: 6px; 
            background: #f8f9fa;
        }
        .tool-name { font-weight: bold; color: #495057; margin-bottom: 10px; }
        .tool-status { padding: 4px 8px; border-radius: 4px; font-size: 0.85em; }
        .status-success { background: #d4edda; color: #155724; }
        .status-warning { background: #fff3cd; color: #856404; }
        .status-error { background: #f8d7da; color: #721c24; }
        .footer { 
            text-align: center; 
            margin-top: 40px; 
            padding: 20px; 
            color: #6c757d; 
            border-top: 1px solid #e9ecef;
        }
        .build-info { 
            background: white; 
            padding: 20px; 
            border-radius: 8px; 
            margin-bottom: 20px; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .build-info a { color: #007bff; text-decoration: none; }
        .build-info a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🛡️ Security Scan Report</h1>
            <p><strong>Project:</strong> $ProjectName</p>
            <p><strong>Scan completed:</strong> $($SecurityData.scan_timestamp)</p>
            <p><strong>Tools executed:</strong> $($SecurityData.tools_run -join ', ')</p>
        </div>

        <div class="build-info">
            <strong>Build Information:</strong><br>
            <a href="$BuildUrl" target="_blank">View Build Details</a>
        </div>

        <div class="summary-cards">
            <div class="card">
                <h3>Critical Issues</h3>
                <div class="number critical">$($SecurityData.critical_issues)</div>
            </div>
            <div class="card">
                <h3>High Issues</h3>
                <div class="number high">$($SecurityData.high_issues)</div>
            </div>
            <div class="card">
                <h3>Medium Issues</h3>
                <div class="number medium">$($SecurityData.medium_issues)</div>
            </div>
            <div class="card">
                <h3>Low Issues</h3>
                <div class="number low">$($SecurityData.low_issues)</div>
            </div>
            <div class="card">
                <h3>Total Issues</h3>
                <div class="number info">$($SecurityData.total_issues)</div>
            </div>
        </div>

        <div class="tools-section">
            <h2>🔧 Security Tools Results</h2>
            <div class="tools-grid">
"@

    # Add tool-specific results if available
    $tools = @("TFSec", "Checkov", "Terrascan", "KICS")
    foreach ($tool in $tools) {
        if ($SecurityData.tools_run -contains $tool) {
            $status = if ($SecurityData.critical_issues -gt 0) { "error" } 
                     elseif ($SecurityData.high_issues -gt 0) { "warning" } 
                     else { "success" }
            
            $statusText = switch ($status) {
                "success" { "Passed" }
                "warning" { "Issues Found" }
                "error" { "Critical Issues" }
            }

            $htmlContent += @"
                <div class="tool-card">
                    <div class="tool-name">$tool</div>
                    <div class="tool-status status-$status">$statusText</div>
                </div>
"@
        }
    }

    $htmlContent += @"
            </div>
        </div>

        <div class="footer">
            <p>Generated by Buildkite Terraform Pipeline</p>
            <p>Timestamp: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC")</p>
        </div>
    </div>
</body>
</html>
"@

    return $htmlContent
}

Write-Host "🔍 Generating security HTML report..."

if (-not (Test-Path $SecuritySummaryJson)) {
    Write-Error "❌ Security summary JSON not found: $SecuritySummaryJson"
}

try {
    $securityData = Get-Content $SecuritySummaryJson | ConvertFrom-Json
    $htmlReport = New-SecurityHtmlReport -SecurityData $securityData -ProjectName $ProjectName -BuildUrl $BuildUrl
    
    # Ensure output directory exists
    $outputDir = Split-Path $OutputPath -Parent
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    $htmlReport | Out-File -FilePath $OutputPath -Encoding UTF8
    
    Write-Host "✅ Security HTML report generated: $OutputPath"
    
    # Display summary
    Write-Host ""
    Write-Host "📊 Security Scan Summary:"
    Write-Host "   Critical: $($securityData.critical_issues)" -ForegroundColor Red
    Write-Host "   High: $($securityData.high_issues)" -ForegroundColor DarkYellow
    Write-Host "   Medium: $($securityData.medium_issues)" -ForegroundColor Yellow
    Write-Host "   Low: $($securityData.low_issues)" -ForegroundColor Green
    Write-Host "   Total: $($securityData.total_issues)"
    
} catch {
    Write-Error "❌ Failed to generate security report: $($_.Exception.Message)"
}

# scripts/generate-policy-report.ps1
# Generates HTML policy validation report

param(
    [string]$PolicyReportJson = "policy-report.json",
    [string]$OutputPath = "policy-report.html",
    [string]$ProjectName = $env:PROJECT_NAME,
    [string]$BuildUrl = $env:BUILDKITE_BUILD_URL
)

$ErrorActionPreference = "Stop"

function New-PolicyHtmlReport {
    param(
        [object]$PolicyData,
        [string]$ProjectName,
        [string]$BuildUrl
    )

    $overallStatus = $PolicyData.overall_result
    $statusColor = if ($overallStatus -eq "passed") { "#28a745" } else { "#dc3545" }
    $statusIcon = if ($overallStatus -eq "passed") { "✅" } else { "❌" }

    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Policy Validation Report - $ProjectName</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
            margin: 0; 
            padding: 20px; 
            background-color: #f8f9fa; 
        }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { 
            background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%); 
            color: white; 
            padding: 30px; 
            border-radius: 10px; 
            margin-bottom: 30px; 
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .header h1 { margin: 0; font-size: 2.5em; }
        .header p { margin: 5px 0; opacity: 0.9; }
        .status-banner { 
            background: $statusColor; 
            color: white; 
            padding: 20px; 
            border-radius: 8px; 
            text-align: center; 
            font-size: 1.5em; 
            font-weight: bold; 
            margin-bottom: 30px;
        }
        .info-section { 
            background: white; 
            padding: 25px; 
            border-radius: 8px; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1); 
            margin-bottom: 30px;
        }
        .namespace-grid { 
            display: grid; 
            gap: 20px; 
            margin-bottom: 30px;
        }
        .namespace { 
            background: white; 
            border: 1px solid #e9ecef; 
            padding: 20px; 
            border-radius: 8px; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .namespace h3 { 
            margin: 0 0 15px 0; 
            color: #333; 
            border-bottom: 2px solid #f8f9fa; 
            padding-bottom: 10px;
        }
        .status-badge { 
            padding: 4px 12px; 
            border-radius: 20px; 
            font-size: 0.85em; 
            font-weight: bold; 
            text-transform: uppercase;
        }
        .status-passed { background: #d4edda; color: #155724; }
        .status-failed { background: #f8d7da; color: #721c24; }
        .status-error { background: #fff3cd; color: #856404; }
        .violation { 
            background: #f8d7da; 
            border-left: 4px solid #dc3545; 
            padding: 15px; 
            margin: 10px 0; 
            border-radius: 4px;
        }
        .warning { 
            background: #fff3cd; 
            border-left: 4px solid #ffc107; 
            padding: 15px; 
            margin: 10px 0; 
            border-radius: 4px;
        }
        .no-issues { 
            background: #d4edda; 
            border-left: 4px solid #28a745; 
            padding: 15px; 
            margin: 10px 0; 
            border-radius: 4px; 
            color: #155724;
        }
        .footer { 
            text-align: center; 
            margin-top: 40px; 
            padding: 20px; 
            color: #6c757d; 
            border-top: 1px solid #e9ecef;
        }
        .build-info { 
            background: white; 
            padding: 20px; 
            border-radius: 8px; 
            margin-bottom: 20px; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .build-info a { color: #007bff; text-decoration: none; }
        .build-info a:hover { text-decoration: underline; }
        .oci-info { 
            background: #e7f3ff; 
            border: 1px solid #b3d9ff; 
            padding: 15px; 
            border-radius: 6px; 
            margin-bottom: 20px;
        }
        .oci-info code { 
            background: #f8f9fa; 
            padding: 2px 6px; 
            border-radius: 3px; 
            font-family: 'Monaco', 'Consolas', monospace;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🛡️ Policy Validation Report</h1>
            <p><strong>Project:</strong> $ProjectName</p>
            <p><strong>Test Time:</strong> $($PolicyData.test_timestamp)</p>
        </div>

        <div class="status-banner">
            $statusIcon Overall Result: $($overallStatus.ToUpper())
        </div>

        <div class="build-info">
            <strong>Build Information:</strong><br>
            <a href="$BuildUrl" target="_blank">View Build Details</a>
        </div>

        <div class="info-section">
            <h2>📦 Policy Package Information</h2>
            <div class="oci-info">
                <strong>OCI Package:</strong> <code>$($PolicyData.oci_package)</code><br>
                <strong>Namespaces Tested:</strong> $($PolicyData.namespaces_tested -join ', ')
            </div>
        </div>

        <div class="info-section">
            <h2>📋 Namespace Results</h2>
            <div class="namespace-grid">
"@

    # Add namespace results
    foreach ($result in $PolicyData.namespace_results) {
        $statusClass = switch ($result.status) {
            "passed" { "status-passed" }
            "failed" { "status-failed" }
            "error" { "status-error" }
        }

        $htmlContent += @"
                <div class="namespace">
                    <h3>
                        Namespace: $($result.namespace)
                        <span class="status-badge $statusClass">$($result.status)</span>
                    </h3>
"@

        if ($result.violations -and $result.violations.Count -gt 0) {
            $htmlContent += "<h4>🚨 Violations:</h4>"
            foreach ($violation in $result.violations) {
                $htmlContent += "<div class='violation'>$($violation.msg)</div>"
            }
        }

        if ($result.warnings -and $result.warnings.Count -gt 0) {
            $htmlContent += "<h4>⚠️ Warnings:</h4>"
            foreach ($warning in $result.warnings) {
                $htmlContent += "<div class='warning'>$($warning.msg)</div>"
            }
        }

        if ($result.status -eq "passed") {
            $htmlContent += "<div class='no-issues'>✅ All policies passed for this namespace</div>"
        }

        if ($result.error) {
            $htmlContent += "<div class='violation'>❌ Error: $($result.error)</div>"
        }

        $htmlContent += "</div>"
    }

    $htmlContent += @"
            </div>
        </div>

        <div class="footer">
            <p>Generated by Buildkite Terraform Pipeline</p>
            <p>Timestamp: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC")</p>
        </div>
    </div>
</body>
</html>
"@

    return $htmlContent
}

Write-Host "🔍 Generating policy validation HTML report..."

if (-not (Test-Path $PolicyReportJson)) {
    Write-Error "❌ Policy report JSON not found: $PolicyReportJson"
}

try {
    $policyData = Get-Content $PolicyReportJson | ConvertFrom-Json
    $htmlReport = New-PolicyHtmlReport -PolicyData $policyData -ProjectName $ProjectName -BuildUrl $BuildUrl
    
    # Ensure output directory exists
    $outputDir = Split-Path $OutputPath -Parent
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    $htmlReport | Out-File -FilePath $OutputPath -Encoding UTF8
    
    Write-Host "✅ Policy validation HTML report generated: $OutputPath"
    
    # Display summary
    Write-Host ""
    Write-Host "📊 Policy Validation Summary:"
    Write-Host "   Overall Result: $($policyData.overall_result)" -ForegroundColor $(if ($policyData.overall_result -eq "passed") { "Green" } else { "Red" })
    Write-Host "   Namespaces Tested: $($policyData.namespaces_tested.Count)"
    
    $failedNamespaces = ($policyData.namespace_results | Where-Object { $_.status -eq "failed" }).Count
    if ($failedNamespaces -gt 0) {
        Write-Host "   Failed Namespaces: $failedNamespaces" -ForegroundColor Red
    }
    
} catch {
    Write-Error "❌ Failed to generate policy validation report: $($_.Exception.Message)"
}

# scripts/generate-cleanup-report.ps1
# Generates cleanup summary report

param(
    [string]$OutputPath = "cleanup-report.json",
    [string]$ProjectName = $env:PROJECT_NAME,
    [int]$RetentionDays = $env:BACKUP_RETENTION_DAYS
)

$ErrorActionPreference = "Stop"

Write-Host "🧹 Generating cleanup report for $ProjectName..."

$cleanupActions = @()
$cleanedFiles = 0
$cleanedSize = 0

# Clean up old artifacts
Write-Host "--- Cleaning up old artifacts"
$cutoffDate = (Get-Date).AddDays(-$RetentionDays)

if (Test-Path "artifacts/") {
    $oldArtifacts = Get-ChildItem "artifacts/" | Where-Object { $_.LastWriteTime -lt $cutoffDate }
    
    foreach ($artifact in $oldArtifacts) {
        $size = if ($artifact.PSIsContainer) { 
            (Get-ChildItem $artifact.FullName -Recurse | Measure-Object -Property Length -Sum).Sum 
        } else { 
            $artifact.Length 
        }
        
        $cleanedSize += $size
        $cleanedFiles++
        
        $cleanupActions += @{
            action = "removed_artifact"
            path = $artifact.FullName
            size_bytes = $size
            last_modified = $artifact.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        Remove-Item $artifact.FullName -Recurse -Force
        Write-Host "  Removed: $($artifact.Name) ($([math]::Round($size / 1KB, 2)) KB)"
    }
} else {
    Write-Host "  No artifacts directory found"
}

# Clean temporary files
Write-Host "--- Cleaning up temporary files"
$tempPatterns = @("*.zip", "*.tar.gz", "*.exe", "*.tmp", "*conftest*", "*terraform-docs*")

foreach ($pattern in $tempPatterns) {
    $tempFiles = Get-ChildItem -Path . -Filter $pattern -ErrorAction SilentlyContinue
    
    foreach ($tempFile in $tempFiles) {
        $cleanedSize += $tempFile.Length
        $cleanedFiles++
        
        $cleanupActions += @{
            action = "removed_temp_file"
            path = $tempFile.FullName
            size_bytes = $tempFile.Length
            pattern = $pattern
        }
        
        Remove-Item $tempFile.FullName -Force
        Write-Host "  Removed temp file: $($tempFile.Name)"
    }
}

# Optimize workspace
Write-Host "--- Optimizing workspace"
if (Test-Path ".terraform/") {
    # Clean .terraform cache but preserve important files
    $terraformCacheFiles = Get-ChildItem ".terraform/" -Recurse -File | Where-Object { 
        $_.Name -like "*.tmp" -or $_.Name -like "*.lock" -or $_.Directory.Name -eq "providers"
    }
    
    foreach ($cacheFile in $terraformCacheFiles) {
        if ($cacheFile.Name -notlike "*.terraform.lock.hcl") {  # Keep lock file
            $cleanedSize += $cacheFile.Length
            $cleanedFiles++
            
            $cleanupActions += @{
                action = "cleaned_terraform_cache"
                path = $cacheFile.FullName
                size_bytes = $cacheFile.Length
            }
            
            Remove-Item $cacheFile.FullName -Force -ErrorAction SilentlyContinue
        }
    }
}

# Generate comprehensive cleanup report
$cleanupReport = @{
    project = $ProjectName
    cleaned_at = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    retention_policy_days = $RetentionDays
    summary = @{
        total_files_cleaned = $cleanedFiles
        total_size_cleaned_bytes = $cleanedSize
        total_size_cleaned_mb = [math]::Round($cleanedSize / 1MB, 2)
        cleanup_actions_count = $cleanupActions.Count
    }
    cleanup_actions = $cleanupActions
    workspace_status = @{
        terraform_directory_exists = (Test-Path ".terraform/")
        artifacts_directory_exists = (Test-Path "artifacts/")
        current_working_directory = (Get-Location).Path
    }
    build_info = @{
        build_url = $env:BUILDKITE_BUILD_URL
        commit = $env:BUILDKITE_COMMIT
        branch = $env:BUILDKITE_BRANCH
    }
}

# Save cleanup report
$cleanupReport | ConvertTo-Json -Depth 4 | Out-File $OutputPath -Encoding UTF8

Write-Host ""
Write-Host "✅ Cleanup completed for $ProjectName"
Write-Host "📊 Cleanup Summary:"
Write-Host "   Files cleaned: $cleanedFiles"
Write-Host "   Space freed: $([math]::Round($cleanedSize / 1MB, 2)) MB"
Write-Host "   Report saved: $OutputPath"

# scripts/send-notification.ps1
# Sends notifications to various channels

param(
    [Parameter(Mandatory)]
    [ValidateSet("slack", "teams", "email", "webhook")]
    [string]$Channel,
    
    [Parameter(Mandatory)]
    [string]$Message,
    
    [string]$Title = "",
    [string]$Color = "good",
    [string]$WebhookUrl = "",
    [hashtable]$Fields = @{},
    [string]$ProjectName = $env:PROJECT_NAME,
    [string]$BuildUrl = $env:BUILDKITE_BUILD_URL
)

$ErrorActionPreference = "Stop"

function Send-SlackNotification {
    param(
        [string]$WebhookUrl,
        [string]$Message,
        [string]$Title,
        [string]$Color,
        [hashtable]$Fields
    )
    
    $slackPayload = @{
        text = if ($Title) { $Title } else { $Message }
        attachments = @(
            @{
                color = $Color
                fields = @()
                footer = "Buildkite Terraform Pipeline"
                ts = [int][double]::Parse((Get-Date -UFormat %s))
            }
        )
    }
    
    # Add custom fields
    foreach ($field in $Fields.GetEnumerator()) {
        $slackPayload.attachments[0].fields += @{
            title = $field.Key
            value = $field.Value
            short = $true
        }
    }
    
    # Add default fields
    $slackPayload.attachments[0].fields += @(
        @{title = "Project"; value = $ProjectName; short = $true},
        @{title = "Build"; value = $BuildUrl; short = $false}
    )
    
    if ($Title) {
        $slackPayload.attachments[0].text = $Message
    }
    
    $jsonPayload = $slackPayload | ConvertTo-Json -Depth 5
    Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $jsonPayload -ContentType "application/json"
}

function Send-TeamsNotification {
    param(
        [string]$WebhookUrl,
        [string]$Message,
        [string]$Title,
        [string]$Color,
        [hashtable]$Fields
    )
    
    $teamsColor = switch ($Color) {
        "good" { "00FF00" }
        "warning" { "FFA500" }
        "danger" { "FF0000" }
        default { "0078D4" }
    }
    
    $teamsPayload = @{
        "@type" = "MessageCard"
        "@context" = "http://schema.org/extensions"
        summary = if ($Title) { $Title } else { $Message }
        themeColor = $teamsColor
        sections = @(
            @{
                activityTitle = if ($Title) { $Title } else { "Terraform Pipeline Notification" }
                activitySubtitle = $ProjectName
                activityImage = "https://www.terraform.io/assets/images/logo-hashicorp-3f10732f.svg"
                text = $Message
                facts = @()
            }
        )
        potentialAction = @(
            @{
                "@type" = "OpenUri"
                name = "View Build"
                targets = @(
                    @{ os = "default"; uri = $BuildUrl }
                )
            }
        )
    }
    
    # Add custom fields as facts
    foreach ($field in $Fields.GetEnumerator()) {
        $teamsPayload.sections[0].facts += @{
            name = $field.Key
            value = $field.Value
        }
    }
    
    $jsonPayload = $teamsPayload | ConvertTo-Json -Depth 5
    Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $jsonPayload -ContentType "application/json"
}

function Send-WebhookNotification {
    param(
        [string]$WebhookUrl,
        [string]$Message,
        [string]$Title,
        [hashtable]$Fields
    )
    
    $webhookPayload = @{
        message = $Message
        title = $Title
        project = $ProjectName
        build_url = $BuildUrl
        timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        fields = $Fields
    }
    
    $jsonPayload = $webhookPayload | ConvertTo-Json -Depth 3
    Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $jsonPayload -ContentType "application/json"
}

# Main notification logic
Write-Host "📤 Sending $Channel notification..."

try {
    switch ($Channel) {
        "slack" {
            if (-not $WebhookUrl) {
                $WebhookUrl = vault kv get -field=webhook_url secret/slack/infrastructure -ErrorAction SilentlyContinue
            }
            if (-not $WebhookUrl) {
                throw "Slack webhook URL not provided and not found in Vault"
            }
            Send-SlackNotification -WebhookUrl $WebhookUrl -Message $Message -Title $Title -Color $Color -Fields $Fields
        }
        
        "teams" {
            if (-not $WebhookUrl) {
                $WebhookUrl = vault kv get -field=webhook_url secret/teams/infrastructure -ErrorAction SilentlyContinue
            }
            if (-not $WebhookUrl) {
                throw "Teams webhook URL not provided and not found in Vault"
            }
            Send-TeamsNotification -WebhookUrl $WebhookUrl -Message $Message -Title $Title -Color $Color -Fields $Fields
        }
        
        "webhook" {
            if (-not $WebhookUrl) {
                throw "Webhook URL must be provided for generic webhook notifications"
            }
            Send-WebhookNotification -WebhookUrl $WebhookUrl -Message $Message -Title $Title -Fields $Fields
        }
        
        "email" {
            Write-Host "⚠️ Email notifications not implemented yet"
            return
        }
    }
    
    Write-Host "✅ $Channel notification sent successfully"
    
} catch {
    Write-Host "❌ Failed to send $Channel notification: $($_.Exception.Message)" -ForegroundColor Red
    # Don't fail the build for notification failures
}
