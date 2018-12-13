
function Get-ProGetUniversalPackage
{
    <#
    .SYNOPSIS
    Gets ProGet universal package information.

    .DESCRIPTION
    The `Get-ProGetUniversalPackage` function gets all the packages in a ProGet universal feed. Pass a ProGet sesion to the `Session` parameter (use `New-ProGetSession` to create a session). Pass the name of the universal feed to the `FeedName` parameter.
    
    You can get information about a specific package by passing its name to the `Name` parameter. Wildcards are supported. If the package is in a group, you must pass the group's name to the `GroupName` parameter. Otherwise, ProGet won't find it (i.e. if you don't pass the group name, ProGet only looks for a package not in a group).

    If the package doesn't exist, you'll get an error.

    To get all the packages in a group, pass the group name to the `GroupName` parameter and nothing to the `Name` parameter. (Note: there is currently a bug in ProGet 4.8.6 where this functionality doesn't work.) 

    You can use wildcards to search for packages with names or in groups. Whenever you do a wildcard search, the function downloads *all* packages from ProGet and searches through them locally. If a wildcard search finds no packages, nothing happens (i.e. you won't see any errors).

    The ProGet API doesn't return a `group` property on objecs that aren't in a group. This function adds a `group` property whose value is an empty string.

    This function uses ProGet's [universal feed API](https://inedo.com/support/documentation/upack/feed-api/endpoints).

    .EXAMPLE
    Get-ProGetUniversalPackage -Session $session -FeedName 'Apps'

    Demonstrates how to get a list of all packages in the `Apps` feed.

    .EXAMPLE
    Get-ProGetUniversalPackage -Session $session -FeedName 'Apps' -Name 'ProGetAutomation'

    Demonstrates how to get a specific package from ProGet that is not in a group. In this case, the `ProGetAutomation` package will be returned. If a package doesn't exist, nothing is returned.

    .EXAMPLE
    Get-ProGetUniversalPackage -Session $session -FeedName 'Apps' -GroupName 'PSModules' -Name 'ProGetAutomation'

    Demonstrates how to get a specific package in a specific group in a universal feed. In this case, will return the `ProGetAutomation` package in the `PSModules` group in the `Apps` feed.

    .EXAMPLE
    Get-ProGetUniversalPackage -Session $session -FeedName 'Apps' -Name 'ProGet*'

    Demonstrates how to get multiple packages using wildcards. In this case, any package that begins with `ProGet` would be returned.

    .EXAMPLE
    Get-ProGetUniversalPackage -Session $session -FeedName 'Apps' -GroupName 'PSModules'

    Demonstrates how to get a list of all packages in a specific group in a universal feed. In this case, all packages in the `PSModules` group in the `Apps` feed will be returned.

    Note: due to a bug in ProGet 4.8.6, no packages will be returned.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]
        # A session object representing the ProGet instance to connect to. Use `New-ProGetSession` to create a new session.
        $Session,

        [Parameter(Mandatory)]
        [string]
        # The name of the feed whose packages to get.
        $FeedName,

        [string]
        # The name of a specific package to get. Wildcards supported. If the package is in a group, you must pass its group name to the `GroupName` parameter
        $Name,

        [string]
        $GroupName
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    
    $searchingName = ($Name -and [WildcardPattern]::ContainsWildcardCharacters($Name))
    $searchingGroup = ($GroupName -and [WildcardPattern]::ContainsWildcardCharacters($GroupName))
    $queryString = ''
    if( -not $searchingName -and -not $searchingGroup )
    {
        $queryString = & {

                                if( $Name )
                                {
                                    'name={0}' -f [uri]::EscapeDataString($Name)
                                }

                                if( $GroupName )
                                {
                                    'group={0}' -f [Uri]::EscapeDataString($GroupName)
                                }
                        }
    }

    if( $queryString )
    {
        $queryString = '?{0}' -f ($queryString -join '&')
    }

    Invoke-ProGetRestMethod -Session $Session -Path ('/upack/{0}/packages{1}' -f [uri]::EscapeDataString($FeedName),$queryString) -Method Get |
        Where-Object {
            if( -not $searchingName )
            {
                return $true
            }

            return $_.name -like $Name
        } |
        Add-PSTypeName -PackageInfo |
        Where-Object {
            if( -not $GroupName -or -not $searchingGroup )
            {
                return $true
            }

            return $_.group -like $GroupName
        }
}
