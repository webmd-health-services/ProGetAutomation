
function Read-ProGetUniversalPackageFile
{
    <#
    .SYNOPSIS
    Reads the contents of a file from a package in a ProGet universal feed.

    .DESCRIPTION
    The `Read-ProGetUniversalPackageFile` reads the contents of a file from a package in a ProGet universal feed. Use this function to read parts of a universal package directly from ProGet without downloading the entire package. Pass the name of the universal feed to the `FeedName` parameter. Pass the name of the package to the `Name` parameter. Pass the path of the file in the package to the `Path` parameter. The path should include the `package` part of the path. ProGet is sensitive to directory separator characters. Make sure you use the same kind as the tool that created your package. 
    
    By default, the file is read from the latest/most recent version of the package. To read a file from a specific version, pass that version to the `Version` parameter.

    This function uses the [Download File Package endpoint](https://inedo.com/support/documentation/upack/feed-api/endpoints#download-package-file) of ProGet's universal API.

    .EXAMPLE
    Read-ProGetUniversalPackageFile -Session $session -FeedName 'Apps' -Name 'MyApp' -Path 'upack.json'

    Demonstrates how to read the upack.json file from a package in a ProGet universal feed without downloading the entire package. In this example, the upack.json file is read from the package.

    .EXAMPLE
    Read-ProGetUniversalPackageFile -Session $session -FeedName 'Apps' -Name 'MyApp' -Path 'package/readme.md'

    Demonstrates how to read the readme.md file that was included in a package.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]
        # A session object that represents the ProGet instance to use. Use the `New-ProGetSession` function to create session objects.
        $Session,

        [Parameter(Mandatory=$true)]
        [string]
        # The name of the feed where the package can be found.
        $FeedName,

        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [string]
        # The package version to check. Defaults to the latest, most recent package.
        $Version,

        [Parameter(Mandatory=$true)]
        [string]
        # The relative path to the file in the package. ProGet is sensitive to directory separator characters. Make sure to use the same kind as the tool that created your package. ProGet sees "package\file" and "package/file" differently.
        $Path
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $uriPath = '/upack/{0}/download-file/{1}/' -f ($FeedName,$Name | ForEach-Object { [Uri]::EscapeUriString($_) })
    if( $Version )
    {
        $uriPath = '{0}{1}/?' -f $uriPath,[Uri]::EscapeUriString($Version)
    }
    else
    {
        $uriPath = '{0}?latest&' -f $uriPath
    }

    $uriPath = '{0}path={1}' -f $uriPath,[Uri]::EscapeUriString($Path)

    Invoke-ProGetRestMethod -Session $Session -Path $uriPath -Parameter @{ } -Method Get -Raw
}
