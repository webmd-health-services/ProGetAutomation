
[CmdletBinding()]
param(
    # You must install your own SQL Server instance.
    [Parameter(Mandatory, ParameterSetName='Windows')]
    [String] $SqlServerName,

    [Parameter(Mandatory, ParameterSetName='Container')]
    [switch] $Container
)

#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
Set-StrictMode -Version 'Latest'

prism install -Path $PSScriptRoot | Format-Table
prism install -Path (Join-Path -Path $PSScriptRoot -ChildPath 'ProGetAutomation') | Format-Table

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'PSModules\Carbon') -Force -Verbose:$false

$version = '25.0.26'

$outputDir = Join-Path -Path $PSScriptRoot -ChildPath '.output'
New-Item -Path $outputDir -ItemType Directory -Force | Write-Verbose

if ($PSCmdlet.ParameterSetName -eq 'Windows')
{
    $runningUnderAppVeyor = (Test-Path -Path 'env:APPVEYOR')

    $dbCredentials = 'Integrated Security=true;'
    if( $runningUnderAppVeyor )
    {
        $dbCredentials = 'User ID=sa;Password=Password12!'
    }

    $hubPath = Join-Path -Path $outputDir -ChildPath 'InedoHub\hub.exe'
    if (-not (Test-Path -Path $hubPath))
    {
        Write-Information 'Downloading InedoHub.'
        $hubZipPath = Join-Path -Path $outputDir -ChildPath 'InedoHub.zip'
        $hubUrl = 'https://proget.inedo.com/upack/Products/download/InedoReleases/DesktopHub?contentOnly=zip&latest'
        Invoke-WebRequest $hubUrl -OutFile $hubZipPath -UseBasicParsing
        Expand-Archive -Path $hubZipPath -DestinationPath ($hubPath | Split-Path)
    }

    if( -not (Test-Path -Path $hubPath) )
    {
        Write-Error -Message 'Failed to download and extract Inedo Hub.'
    }

    & $hubPath 'install' `
            "ProGet:$($version)" `
            --ConnectionString="Server=$($SqlServerName); $($dbCredentials)"

    Get-Service -Name 'InedoProget*' | Start-Service
}
else
{
    $containerImage = "proget.inedo.com/productimages/inedo/proget:${version}"
    Write-Information "Starting ProGet from container image: ${containerImage}"
    docker run --name proget --rm --detach --publish 8624:80 $containerImage

    Write-Information 'Container started.'
    Write-Information 'Waiting 30 seconds for ProGet to start up...'
    Start-Sleep -Seconds 30

    Invoke-WebRequest -Uri 'http://localhost:8624' -UseBasicParsing
}

$pgutilAssetName = 'pgutil-win-x64.zip'
if ((Get-Variable -Name 'IsLinux' -ErrorAction Ignore) -and $IsLinux)
{
    $pgutilAssetName = 'pgutil-linux-x64.zip'
}

$latestPgutilRelease = Invoke-RestMethod -Uri 'https://api.github.com/repos/Inedo/pgutil/releases/latest'
$asset = $latestPgutilRelease.assets | Where-Object Name -EQ $pgutilAssetName
$pgutilZipPath = Join-Path -Path $outputDir -ChildPath 'pgutil.zip'
$pgutilOutputPath = Join-Path -Path $outputDir -ChildPath 'pgutil'
Write-Information "Downloading pgutil $($latestPgutilRelease.tag_name)"
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $pgutilZipPath -UseBasicParsing
Expand-Archive -Path $pgutilZipPath -DestinationPath $pgutilOutputPath -Force

Push-Location -Path $pgutilOutputPath
try
{
    if ((Get-Variable -Name 'IsLinux' -ErrorAction Ignore) -and $IsLinux)
    {
        chmod +x pgutil
    }

    ./pgutil sources add --name=Default --url=http://localhost:8624/

    Write-Information 'Adding ProGet license key.'
    ./pgutil settings set --name=Licensing.Key --value=MCTT2MUA-2Y72-F16311-S89JKR-KJWRU50W

    Write-Information 'Creating API key to use for tests.'
    $apiKey = ./pgutil apikeys create system
    $apiKey = $apiKey.Trim()
    Write-Verbose "API key: ${apiKey}"

    $apiKeyFilePath = Join-Path -Path $PSScriptRoot -ChildPath 'test_api_key.txt'
    [IO.File]::WriteAllText($apiKeyFilePath, $apiKey)
}
finally
{
    Pop-Location
}

