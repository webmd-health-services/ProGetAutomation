
function New-ProGetSession
{
    <#
    .SYNOPSIS
    Creates a session object used to connect with a ProGet instance.

    .DESCRIPTION
    The `New-ProGetSession` function creates and returns a session object that is required when calling any function in
    the ProGetAutomation module that communicates with ProGet. The session includes ProGet's URL and the
    credentials and/or API key to use when making requests.

    .EXAMPLE
    $session = New-ProGetSession -Url 'https://proget.com' -Credential $credential

    Demonstrates how to call `New-ProGetSession`. In this case, the returned session object can be passed to other
    ProGetAutomation module functions to communicate with ProGet at `https://proget.com` with the credential in
    `$credential`.
    #>
    [CmdletBinding()]
    param(
        # The URL to the ProGet instance to use.
        [Parameter(Mandatory)]
        [Alias('Uri')]
        [uri] $Url,

        # The credential to use when making requests to ProGet utilizing the Universal Feed API.
        [pscredential] $Credential,

        # The API key to use when making requests to ProGet utilizing the Native API
        [string] $ApiKey
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    return [pscustomobject]@{
            Url = $Url;
            Credential = $Credential;
            ApiKey = $ApiKey
        } |
        Add-Member -MemberType AliasProperty -Name 'Uri' -Value 'Url' -PassThru
}
