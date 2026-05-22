[CmdletBinding()]
param(
  [string]$Repo = "bluestreakxmu/oci-free-arm-instance",
  [string]$ConfigPath = "",
  [string]$WorkflowFile = "create-vm.yml",
  [string]$Branch = "main",
  [switch]$TriggerWorkflow,
  [switch]$SkipGitHubCliInstall
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
  $ConfigPath = Join-Path $PSScriptRoot "secrets.local.json"
}

function Write-Step {
  param([string]$Message)
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Get-RequiredProperty {
  param(
    [object]$Config,
    [string]$Name
  )

  $value = $Config.$Name
  if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
    throw "Missing required value '$Name' in $ConfigPath."
  }

  return [string]$value
}

function Ensure-GitHubCli {
  if (Get-Command gh -ErrorAction SilentlyContinue) {
    return
  }

  if ($SkipGitHubCliInstall) {
    throw "GitHub CLI (gh) is not installed. Install it first, then rerun this script."
  }

  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI (gh) is not installed, and winget was not found. Install gh manually: https://cli.github.com/"
  }

  Write-Step "Installing GitHub CLI with winget"
  winget install --id GitHub.cli -e --source winget --accept-package-agreements --accept-source-agreements

  $candidatePaths = @(
    "$env:ProgramFiles\GitHub CLI",
    "$env:LOCALAPPDATA\Programs\GitHub CLI"
  )

  foreach ($path in $candidatePaths) {
    if (Test-Path (Join-Path $path "gh.exe")) {
      $env:PATH = "$path;$env:PATH"
    }
  }

  if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI installation finished, but gh is still not on PATH. Open a new PowerShell window and rerun this script."
  }
}

function Ensure-GitHubAuth {
  Write-Step "Checking GitHub authentication"
  & gh auth status *> $null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "GitHub CLI is not authenticated. A browser login will open now." -ForegroundColor Yellow
    & gh auth login --hostname github.com --web --git-protocol https
    if ($LASTEXITCODE -ne 0) {
      throw "GitHub authentication failed."
    }
  }
}

function Set-RepoSecret {
  param(
    [string]$Name,
    [string]$Value
  )

  if ([string]::IsNullOrWhiteSpace($Value)) {
    Write-Host "Skipping empty secret $Name" -ForegroundColor Yellow
    return
  }

  $tempFile = New-TemporaryFile
  try {
    [System.IO.File]::WriteAllText($tempFile.FullName, $Value, [System.Text.UTF8Encoding]::new($false))
    Get-Content -LiteralPath $tempFile.FullName -Raw | & gh secret set $Name --repo $Repo
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to set GitHub secret $Name."
    }
    Write-Host "Set secret $Name"
  }
  finally {
    Remove-Item -LiteralPath $tempFile.FullName -Force -ErrorAction SilentlyContinue
  }
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
  $examplePath = Join-Path $PSScriptRoot "secrets.example.json"
  throw "Config file not found: $ConfigPath. Copy $examplePath to $ConfigPath, fill in your values, then rerun this script."
}

Write-Step "Reading local secret configuration"
$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json

$secretValues = [ordered]@{
  OCI_COMPARTMENT_ID   = Get-RequiredProperty $config "OCI_COMPARTMENT_ID"
  IMAGE_ID             = Get-RequiredProperty $config "IMAGE_ID"
  OCI_SUBNET_ID        = Get-RequiredProperty $config "OCI_SUBNET_ID"
  AD_NAME              = Get-RequiredProperty $config "AD_NAME"
  SSH_PUBLIC_KEY       = Get-RequiredProperty $config "SSH_PUBLIC_KEY"
  OCI_CLI_REGION       = Get-RequiredProperty $config "OCI_CLI_REGION"
  OCI_CLI_USER         = Get-RequiredProperty $config "OCI_CLI_USER"
  OCI_CLI_TENANCY      = Get-RequiredProperty $config "OCI_CLI_TENANCY"
  OCI_CLI_FINGERPRINT  = Get-RequiredProperty $config "OCI_CLI_FINGERPRINT"
}

if ($config.OCI_CLI_KEY_CONTENT -and -not [string]::IsNullOrWhiteSpace([string]$config.OCI_CLI_KEY_CONTENT)) {
  $secretValues["OCI_CLI_KEY_CONTENT"] = [string]$config.OCI_CLI_KEY_CONTENT
}
elseif ($config.OCI_CLI_KEY_FILE -and -not [string]::IsNullOrWhiteSpace([string]$config.OCI_CLI_KEY_FILE)) {
  $keyPath = [Environment]::ExpandEnvironmentVariables([string]$config.OCI_CLI_KEY_FILE)
  if (-not (Test-Path -LiteralPath $keyPath)) {
    throw "OCI_CLI_KEY_FILE does not exist: $keyPath"
  }
  $secretValues["OCI_CLI_KEY_CONTENT"] = Get-Content -LiteralPath $keyPath -Raw
}
else {
  throw "Provide either OCI_CLI_KEY_CONTENT or OCI_CLI_KEY_FILE in $ConfigPath."
}

if ($config.DISCORD_WEBHOOK_URL -and -not [string]::IsNullOrWhiteSpace([string]$config.DISCORD_WEBHOOK_URL)) {
  $secretValues["DISCORD_WEBHOOK_URL"] = [string]$config.DISCORD_WEBHOOK_URL
}

if ($config.TELEGRAM_BOT_TOKEN -and -not [string]::IsNullOrWhiteSpace([string]$config.TELEGRAM_BOT_TOKEN)) {
  $secretValues["TELEGRAM_BOT_TOKEN"] = [string]$config.TELEGRAM_BOT_TOKEN
}

if ($config.TELEGRAM_CHAT_ID -and -not [string]::IsNullOrWhiteSpace([string]$config.TELEGRAM_CHAT_ID)) {
  $secretValues["TELEGRAM_CHAT_ID"] = [string]$config.TELEGRAM_CHAT_ID
}

Ensure-GitHubCli
Ensure-GitHubAuth

Write-Step "Setting GitHub Actions secrets for $Repo"
foreach ($secret in $secretValues.GetEnumerator()) {
  Set-RepoSecret -Name $secret.Key -Value $secret.Value
}

if ($TriggerWorkflow) {
  Write-Step "Triggering workflow $WorkflowFile on $Branch"
  & gh workflow run $WorkflowFile --repo $Repo --ref $Branch
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to trigger workflow $WorkflowFile."
  }
}

Write-Step "Done"
Write-Host "Open https://github.com/$Repo/actions/workflows/$WorkflowFile to monitor the run."
