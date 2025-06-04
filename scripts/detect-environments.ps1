# detect-environments.ps1
# This script automatically detects available environments from the filesystem
# and generates the environments list for the pipeline

# Get all environment directories
$environments = Get-ChildItem -Path "./environments" -Directory | 
    Where-Object { $_.Name -notin @("examples", "templates", "test") } | 
    Sort-Object Name

# Generate environments list for pipeline
$envList = @()
foreach ($env in $environments) {
    $envList += @{
        name = $env.Name
        path = $env.FullName
    }
}

# Output environments in a format Buildkite can use
Write-Host "environments:"
foreach ($env in $envList) {
    Write-Host "  - '$($env.name)'"
}
