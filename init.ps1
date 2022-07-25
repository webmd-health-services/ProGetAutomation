[CmdletBinding()]
param(
    # You must install your own SQL Server instance.
    [Parameter(Mandatory)]
    [String] $SqlServerName
)

#Requires -RunAsAdministrator
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& {
    $VerbosePreference = 'SilentlyContinue'
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'PSModules\Carbon') -Force
}

$version = '6.0.18'

$runningUnderAppVeyor = (Test-Path -Path 'env:APPVEYOR')

$dbCredentials = 'Integrated Security=true;'
if( $runningUnderAppVeyor )
{
    $dbCredentials = 'User ID=sa;Password=Password12!'
}

$hubPath = Join-Path -Path $PSScriptRoot -ChildPath '.output\InedoHub\hub.exe'
if( -not (Test-Path -Path $hubPath) )
{
    $hubZipPath = Join-Path -Path $PSScriptRoot -ChildPath '.output\InedoHub.zip'
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
