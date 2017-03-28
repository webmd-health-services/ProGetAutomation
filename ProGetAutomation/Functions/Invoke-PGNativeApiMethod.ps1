
function Invoke-PGNativeApiMethod
{
    <#
    .SYNOPSIS
    Calls a method on ProGet's "native" API.

    .DESCRIPTION
    The `Invoke-PGNativeApiMethod` calls a method on BuildMaster's "native" API. From Inedo:

    > This API endpoint should be avoided if there is an alternate API endpoint available, as those are much easier to use and will likely not change.

    In other words, use a native API at your own peril.

    .EXAMPLE
    Invoke-PGNativeApiMethod -Session $session -Name 'Feeds_CreateOrUpdateProGetFeed' -Parameter @{ Feed_Name = 'Apps' }

    Demonstrates how to call `Invoke-PGNativeApiMethod`. In this example, it is calling the `Feeds_CreateOrUpdateProGetFeed` method to create a new Universal feed named `Apps`.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]
        # A session object that represents the ProGet instance to use. Use the `New-PGSession` function to create session objects.
        $Session,

        [Parameter(Mandatory=$true)]
        [string]
        # The name of the API method to use. The list can be found at http://inedo.com/support/documentation/proget/reference/api/native
        $Name,

        [Microsoft.PowerShell.Commands.WebRequestMethod]
        # The HTTP/web method to use. The default is `POST`.
        $Method = [Microsoft.PowerShell.Commands.WebRequestMethod]::Post,

        [Parameter(Mandatory=$true)]
        [hashtable]
        $Parameter
    )

    Set-StrictMode -Version 'Latest'

    Invoke-PGRestMethod -Session $Session -Name ('json/{0}' -f $Name) -Method $Method -Parameter $Parameter -AsJson

}