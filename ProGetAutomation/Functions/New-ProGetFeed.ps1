
function New-ProGetFeed
{
    <#
    .SYNOPSIS
    Creates a new ProGet package feed

    .DESCRIPTION
    The `New-ProGetFeed` function creates a new ProGet feed. Use the `Type` parameter to specify the feed type. The
    `Session` parameter controls the instance of ProGet to connect to. This function uses ProGet's Native API, so an API
    key is required. Use `New-ProGetSession` to create a session with your API key.

    [Valid feed types are listed in the Feed Management API documentation.](https://docs.inedo.com/docs/proget-reference-api-feed-management)
    In April 2023, valid feed types were:

    * asset
    * chocolatey
    * docker
    * helm
    * maven
    * npm
    * nuget
    * powershell
    * pypi
    * romp
    * rubygems
    * universal
    * vsix

    .EXAMPLE
    New-ProGetFeed -Session $ProGetSession -Name 'Apps' -Type 'ProGet'

    Demonstrates how to call `New-ProGetFeed`. In this case, a new Universal package feed named 'Apps' will be created
    for the specified ProGet Uri
    #>
    [CmdletBinding()]
    param(
        # The session includes ProGet's URI and the API key. Use `New-ProGetSession` to create session objects
        [Parameter(Mandatory)]
        [pscustomobject] $Session,

        # The feed name indicates the name of the package feed that will be created.
        [Parameter(Mandatory)]
        [Alias('FeedName')]
        [string] $Name,

        # The feed type indicates the type of package feed to create.
        # [Valid feed types are listed in the Feed Management API documentation.](https://docs.inedo.com/docs/proget-reference-api-feed-management)
        # In April 2023, valid feed types were:
        #
        # * asset
        # * chocolatey
        # * docker
        # * helm
        # * maven
        # * npm
        # * nuget
        # * powershell
        # * pypi
        # * romp
        # * rubygems
        # * universal
        # * vsix
        [Parameter(Mandatory)]
        [Alias('FeedType')]
        [string] $Type
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if ($Type -eq 'ProGet')
    {
        $msg = 'ProGet renamed its "ProGet" feed type name to "Universal". Please update the value of ' +
               'New-ProGetFeed''s "Type" parameter from "ProGet" to "Universal".'
        Write-Warning $msg
        $Type = 'Universal'
    }

    $Type = $Type.ToLowerInvariant()

    $feedExists = Test-ProGetFeed -Session $Session -Name $Name
    if ($feedExists)
    {
        $msg = "Unable to create ${Type} feed ""${Name}"" because a feed with that name already exists."
        Write-Error $msg -ErrorAction $ErrorActionPreference
        return
    }

    $body = [pscustomobject]@{
        name = $name;
        feedType = $Type;
        active = $true;
    } | ConvertTo-Json

    Write-Information -Message "[$($Session.Url)]  Creating ${Type} feed ""${Name}""."
    Invoke-ProGetRestMethod -Session $Session -Path '/api/management/feeds/create' -Method Post -Body $body
}
