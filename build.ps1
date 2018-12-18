[CmdletBinding(DefaultParameterSetName='Build')]
param(
    [Parameter(Mandatory=$true,ParameterSetName='Clean')]
    [Switch]
    # Runs the build in clean mode, which removes any files, tools, packages created by previous builds.
    $Clean,

    [Parameter(Mandatory=$true,ParameterSetName='Initialize')]
    [Switch]
    # Initializes the repository.
    $Initialize
)


#Requires -Version 4
Set-StrictMode -Version Latest

& (Join-Path -Path $PSScriptRoot -ChildPath '.whiskey\Import-Whiskey.ps1' -Resolve)

$configPath = Join-Path -Path $PSScriptRoot -ChildPath 'whiskey.yml' -Resolve

$optionalArgs = @{ }
if( $Clean )
{
    $optionalArgs['Clean'] = $true
}

if( $Initialize )
{
    $optionalArgs['Initialize'] = $true
}

$context = New-WhiskeyContext -Environment 'Dev' -ConfigurationPath $configPath
$apiKeys = @{
                'powershellgallery.com' = 'POWERSHELL_GALLERY_API_KEY';
                'github.com' = 'GITHUB_ACCESS_TOKEN'
            }
foreach( $apiKeyID in $apiKeys.Keys )
{
    $envVarName = $apiKeys[$apiKeyID]
    $envVarPath = 'env:{0}' -f $envVarName
    if( -not (Test-Path -Path $envVarPath) )
    {
        continue
    }

    Write-Verbose ('Adding API key "{0}" from environment variable "{1}".' -f $apiKeyID,$envVarName)
    Add-WhiskeyApiKey -Context $context -ID $apiKeyID -Value (Get-Item -Path $envVarPath).Value
}
Invoke-WhiskeyBuild -Context $context @optionalArgs
