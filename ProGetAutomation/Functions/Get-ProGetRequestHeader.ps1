
function Get-ProGetRequestHeader
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Object] $Session
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $headers = @{}

    if ($Session.ApiKey)
    {
        $headers['X-ApiKey'] = $Session.ApiKey;
    }

    if ($Session.Credential)
    {
        $credential = "$($Session.Credential.UserName):$($Session.Credential.GetNetworkCredential().Password)"
        $bytes = [Text.Encoding]::UTF8.GetBytes($credential)
        $headers['Authorization'] = "Basic $([Convert]::ToBase64String($bytes))"

        if (-not $Session.ApiKey)
        {
            $headers['X-ApiKey'] = $credential
        }
    }

    return $headers
}