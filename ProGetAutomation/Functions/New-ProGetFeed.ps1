
function New-ProGetFeed
{
    <#
    .SYNOPSIS
    Creates a new ProGet package feed

    .DESCRIPTION
    The `New-ProGetFeed` function creates a new ProGet feed. Use the `Type` parameter to specify the feed type (valid values are 'VSIX', 'RubyGems', 'Docker', 'ProGet', 'Maven', 'Bower', 'npm', 'Deployment', 'Chocolatey', 'NuGet', 'PowerShell'). The `Session` parameter controls the instance of ProGet to connect to. This function uses ProGet's Native API, so an API key is required. Use `New-ProGetSession` to create a session with your API key.

    .EXAMPLE
    New-ProGetFeed -Session $ProGetSession -Name 'Apps' -Type 'ProGet'

    Demonstrates how to call `New-ProGetFeed`. In this case, a new Universal package feed named 'Apps' will be created for the specified ProGet Uri
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
        # Valid feed types are ('VSIX', 'RubyGems', 'Docker', 'ProGet', 'Maven', 'Bower', 'npm', 'Deployment', 'Chocolatey', 'NuGet', 'PowerShell') - check here for a latest list - https://inedo.com/support/documentation/proget/feed-types/universal
        [Parameter(Mandatory)]
        [Alias('FeedType')]
        [string] $Type
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if( -not $Session.ApiKey )
    {
        Write-Error -Message ('We are unable to create new package feed ''{0}/{1}'' because your ProGet session is missing an API key. This function uses ProGet''s Native API, which requires an API key. Use `New-ProGetSession` to create a session object that uses an API key.' -f $Type, $Name)
        return
    }

    if( $Type -eq 'ProGet' )
    {
        $msg = 'ProGet renamed its "ProGet" feed type name to "Universal". Please update the value of ' +
               'New-ProGetFeed''s "Type" parameter from "ProGet" to "Universal".'
        Write-Warning $msg
        $Type = 'Universal'
    }

    $Parameters = @{
                        'FeedType_Name' = $Type;
                        'Feed_Name' = $Name;
                    }

    $feedExists = Test-ProGetFeed -Session $Session -Name $Name -Type $Type
    if( $feedExists )
    {
        Write-Error -Message ('Unable to create {0} {1} feed: a feed with that name and type already exists.' -f $Type, $Name) -ErrorAction $ErrorActionPreference
        return
    }
    Write-Verbose -Message ('Creating {0} {1} feed in ProGet instance "{2}".' -f $Type, $Name, $Session.Uri)
    $null = Invoke-ProGetNativeApiMethod -Session $Session -Name 'Feeds_CreateFeed' -Parameter $Parameters

}
