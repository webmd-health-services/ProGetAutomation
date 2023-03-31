
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

    if( $Session.ApiKey )
    {
        $headers['X-ApiKey'] = $Session.ApiKey;
    }

    if( $Session.Credential )
    {
        $bytes = [Text.Encoding]::UTF8.GetBytes(('{0}:{1}' -f $Session.Credential.UserName,$Session.Credential.GetNetworkCredential().Password))
        $creds = 'Basic ' + [Convert]::ToBase64String($bytes)
        $headers['Authorization'] = $creds
    }

    return $headers
}