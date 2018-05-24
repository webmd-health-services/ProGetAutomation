
function Invoke-ProGetRestMethod
{
    <#
    .SYNOPSIS
    Invokes a ProGet REST method.

    .DESCRIPTION
    The `Invoke-ProGetRestMethod` invokes a ProGet REST API method. You pass the path to the endpoint (everything after `/api/`) via the `Name` parameter, the HTTP method to use via the `Method` parameter, and the parameters to pass in the body of the request via the `Parameter` parameter.  This function converts the `Parameter` hashtable to JSON and sends it in the body of the request.

    You also need to pass an object that represents the ProGet instance and API key to use when connecting via the `Session` parameter. Use the `New-ProGetSession` function to create a session object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]
        # A session object that represents the ProGet instance to use. Use the `New-ProGetSession` function to create session objects.
        $Session,

        [Parameter(Mandatory=$true)]
        [string]
        # The path to the API endpoint.
        $Path,

        [Microsoft.PowerShell.Commands.WebRequestMethod]
        # The HTTP/web method to use. The default is `POST`.
        $Method = [Microsoft.PowerShell.Commands.WebRequestMethod]::Post,

        [hashtable]
        # The parameters to pass to the method.
        $Parameter,

        [string]
        [ValidateSet('Form','Json')]
        # Controls how the parameters are sent to the API. The default is `Form`, which sends them as URL-encoded name/value pairs (i.e. like a HTML form submission). The other options is `Json`, which converts the parameters to JSON and sends that JSON text as the content/body of the request. This parameter is ignored if there are no parmaeters to send or if the `InFile` parameter is used.
        $ContentType,
        
        # Sends the contents of the file at this path as the body of the web request.
        [String]
        $InFile,

        [Switch]
        # Return the raw content from the request instead of attempting to convert the response from JSON into an object.
        $Raw
    )

    Set-StrictMode -Version 'Latest'

    $uri = New-Object 'Uri' -ArgumentList $Session.Uri,$Path
    
    $requestContentType = 'application/json; charset=utf-8'
    $bodyParam = @{ }
    $body = ''
    $debugBody = ''
    if( $Parameter )
    {
        if( $ContentType -eq 'Json' )
        {
            $body = $Parameter | ConvertTo-Json -Depth 100
            $debugBody = $body -replace '("API_Key": +")[^"]+','$1********'
        }
        else
        {
            $body = $Parameter.Keys | ForEach-Object { '{0}={1}' -f [Web.HttpUtility]::UrlEncode($_),[Web.HttpUtility]::UrlEncode($Parameter[$_]) }
            $body = $body -join '&'
            $requestContentType = 'application/x-www-form-urlencoded; charset=utf-8'
            $debugBody = $Parameter.Keys | ForEach-Object {
                $value = $Parameter[$_]
                if( $_ -eq 'API_Key' )
                {
                    $value = '********'
                }
                '    {0}={1}' -f $_,$value }
        }
    }

    $headers = @{ }

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

    #$DebugPreference = 'Continue'
    Write-Debug -Message ('{0} {1}' -f $Method.ToString().ToUpperInvariant(),($uri -replace '\b(API_Key=)([^&]+)','$1********'))
    Write-Debug -Message ('    Content-Type: {0}' -f $requestContentType)
    foreach( $headerName in $headers.Keys )
    {
        $value = $headers[$headerName]
        if( @( 'X-ApiKey', 'Authorization' ) -contains $headerName )
        {
            $value = '*' * 8
        }

        Write-Debug -Message ('    {0}: {1}' -f $headerName,$value)
    }
    
    if( $debugBody )
    {
        $debugBody | Write-Verbose
    }

    $errorsAtStart = $Global:Error.Count
    try
    {
        $bodyParam = @{ }
        if( $body )
        {
            $bodyParam['Body'] = $body
        }
        elseif( $Infile )
        {
            $body = @{ }
            $bodyParam['Infile'] = $Infile
            $requestContentType = 'multipart/form-data'
        }
        $credentialParam = @{ }
        if( $Session.Credential )
        {
            $credentialParam['Credential'] = $Session.Credential
        }

        $cmdName = 'Invoke-RestMethod'
        if( $Raw )
        {
            $cmdName = 'Invoke-WebRequest'
        }

        & $cmdName -Method $Method -Uri $uri @bodyParam -ContentType $requestContentType -Headers $headers @credentialParam | 
            ForEach-Object { $_ } 
    }
    catch [Net.WebException]
    {
        for( $idx = $errorsAtStart; $idx -lt $Global:Error.Count; ++$idx )
        {
            $Global:Error.RemoveAt(0)
        }

        Write-Error -ErrorRecord $_ -ErrorAction $ErrorActionPreference
    }
}
