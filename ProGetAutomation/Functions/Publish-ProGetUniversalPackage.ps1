
function Publish-ProGetUniversalPackage
{
    <#
    .SYNOPSIS
    Publishes a package to the specified ProGet instance

    .DESCRIPTION
    The `Publish-ProGetUniversalPackage` function will upload a package to the specified Proget instance/feed.

    .EXAMPLE
    Publish-ProGetUniversalPackage -ProGetSession $ProGetSession -FeedName 'Apps' -PackagePath 'C:\ProGetPackages\TestPackage.upack'

    Demonstrates how to call `Publish-ProGetUniversalPackage`. In this case, the package named 'TestPackage.upack' will be published to the 'Apps' feed located at $ProGetSession.Uri using the #ProGetSession.Credential authentication credentials
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [pscustomobject]
        # The session includes ProGet's URI and the credentials to use when utilizing ProGet's API.
        $ProGetSession,

        [Parameter(Mandatory=$true)]
        [string]
        # The feed name indicates the appropriate feed where the package should be published.
        $FeedName,

        [Parameter(Mandatory=$true)]
        [string]
        # The path to the package that will be published to ProGet.
        $PackagePath
    )

    Set-StrictMode -Version 'Latest'
    
    $shouldProcessCaption = ('creating {0} package' -f $PackagePath)
    $proGetPackageUri = [String]$ProGetSession.Uri + 'upack/' + $FeedName
    if (!$ProGetSession.Credential)
    {
        throw ('Failed to upload ''{0}'' package to ProGet {1}. ''ProGetSession'' parameter must contain a PSCredential object with a user name and password.' -f ($PackagePath | Split-Path -Leaf), $proGetPackageUri)
    }
    $proGetCredential = $ProGetSession.Credential

    $headers = @{}
    $bytes = [Text.Encoding]::UTF8.GetBytes(('{0}:{1}' -f $proGetCredential.UserName,$proGetCredential.GetNetworkCredential().Password))
    $creds = 'Basic ' + [Convert]::ToBase64String($bytes)
    $headers.Add('Authorization', $creds)
    
    $operationDescription = 'Uploading ''{0}'' package to ProGet {1}' -f ($PackagePath | Split-Path -Leaf), $proGetPackageUri
    if( $PSCmdlet.ShouldProcess($operationDescription, $operationDescription, $shouldProcessCaption) )
    {
    
        Write-Verbose -Message ('PUT {0}' -f $proGetPackageUri)
    
        $result = Invoke-RestMethod -Method Put `
                                    -Uri $proGetPackageUri `
                                    -ContentType 'application/octet-stream' `
                                    -Body ([IO.File]::ReadAllBytes($PackagePath)) `
                                    -Headers $headers
        if( -not $? -or ($result -and $result.StatusCode -ne 201) )
        {
            throw ('Failed to upload ''{0}'' package to {1}:{2}{3}' -f ($PackagePath | Split-Path -Leaf),$proGetPackageUri,[Environment]::NewLine,($result | Format-List * -Force | Out-String))
        }
    }
}