[CmdletBinding()]
param(
    # You must install your own SQL Server instance.
    [Parameter(Mandatory)]
    [String] $SqlServerName
)

#Requires -RunAsAdministrator
#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
Set-StrictMode -Version 'Latest'

prism install -Path $PSScriptRoot | Format-Table
prism install -Path (Join-Path -Path $PSScriptRoot -ChildPath 'ProGetAutomation') | Format-Table

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'PSModules\Carbon') -Force -Verbose:$false

$version = '24.0.36'

$runningUnderAppVeyor = (Test-Path -Path 'env:APPVEYOR')

$dbCredentials = 'Integrated Security=true;'
if( $runningUnderAppVeyor )
{
    $dbCredentials = 'User ID=sa;Password=Password12!'
}

$outputDir = Join-Path -Path $PSScriptRoot -ChildPath '.output'
New-Item -Path $outputDir -ItemType Directory -Force | Write-Verbose

$hubPath = Join-Path -Path $outputDir -ChildPath 'InedoHub\hub.exe'
if (-not (Test-Path -Path $hubPath))
{
    Write-Information 'Downloading InedoHub.'
    $hubZipPath = Join-Path -Path $outputDir -ChildPath 'InedoHub.zip'
    $hubUrl = 'https://proget.inedo.com/upack/Products/download/InedoReleases/DesktopHub?contentOnly=zip&latest'
    Invoke-WebRequest $hubUrl -OutFile $hubZipPath
    Expand-Archive -Path $hubZipPath -DestinationPath ($hubPath | Split-Path)
}

if( -not (Test-Path -Path $hubPath) )
{
    Write-Error -Message 'Failed to download and extract Inedo Hub.'
}

# Free edition license
& $hubPath 'install' `
           "ProGet:$($version)" `
           --ConnectionString="Server=$($SqlServerName); $($dbCredentials)" `
           --LicenseKey=MCTT2MUA-2Y72-F16311-S89JKR-KJWRU50W

Get-Service -Name 'InedoProget*' | Start-Service

Write-Information 'Downloading pgutil.'
$latestPgutilRelease = Invoke-RestMethod -Uri 'https://api.github.com/repos/Inedo/pgutil/releases/latest'
$asset = $latestPgutilRelease.assets | Where-Object Name -EQ 'pgutil-win-x64.zip'
$pgutilZipPath = Join-Path -Path $outputDir -ChildPath 'pgutil.zip'
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $pgutilZipPath
Expand-Archive -Path $pgutilZipPath -DestinationPath (Join-Path -Path $outputDir -ChildPath 'pgutil') -Force
$pgutilExe = Join-Path -Path $outputDir -ChildPath 'pgutil\pgutil.exe' -Resolve

Write-Information 'Creating API key.'
& $pgutilExe sources add --name=Default --url=http://localhost:8624/
$apiKey = & $pgutilExe apikeys create system
$apiKey = $apiKey.Trim()
Write-Verbose "API key: ${apiKey}"

$apiKeyFilePath = Join-Path -Path $PSScriptRoot -ChildPath 'test_api_key.txt'
[IO.File]::WriteAllText($apiKeyFilePath, $apiKey)
