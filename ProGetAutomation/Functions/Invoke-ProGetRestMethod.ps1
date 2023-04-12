
function Invoke-ProGetRestMethod
{
    <#
    .SYNOPSIS
    Invokes a ProGet REST method.

    .DESCRIPTION
    The `Invoke-ProGetRestMethod` invokes a ProGet REST API method. You pass the path to the endpoint (everything after
    `/api/`) via the `Name` parameter, the HTTP method to use via the `Method` parameter, and the parameters to pass in
    the body of the request via the `Parameter` parameter.  This function converts the `Parameter` hashtable to JSON and
    sends it in the body of the request.

    You also need to pass an object that represents the ProGet instance and API key to use when connecting via the
    `Session` parameter. Use the `New-ProGetSession` function to create a session object.
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName='None')]
    param(
        # A session object that represents the ProGet instance to use. Use the `New-ProGetSession` function to create
        # session objects.
        [Parameter(Mandatory)]
        [object] $Session,

        # The path to the API endpoint.
        [Parameter(Mandatory)]
        [String] $Path,

        # The HTTP/web method to use. The default is `POST`.
        [WebRequestMethod] $Method = [WebRequestMethod]::Post,

        # The parameters to pass to the method.
        [Parameter(ParameterSetName='ByParameter')]
        [hashtable] $Parameter,

        # Controls how the parameters are sent to the API. The default is `Form`, which sends them as URL-encoded
        # name/value pairs (i.e. like a HTML form submission). The other options is `Json`, which converts the
        # parameters to JSON and sends that JSON text as the content/body of the request. This parameter is ignored if
        # there are no parmaeters to send or if the `InFile` parameter is used.
        [Parameter(ParameterSetName='ByParameter')]
        [ValidateSet('Form','Json')]
        [String] $ContentType,

        # Send the contents of the file at this path as the body of the web request.
        [Parameter(ParameterSetName='ByFile')]
        [String] $InFile,

        # Send the content of this string as the body of the web request.
        [Parameter(ParameterSetName='ByContent')]
        [String] $Body,

        # Return the raw content from the request instead of attempting to convert the response from JSON into an
        # object.
        [switch] $Raw
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $uri = New-Object 'Uri' -ArgumentList $Session.Url,$Path

    $requestContentType = 'application/json'
    $debugBody = $null

    if( $PSCmdlet.ParameterSetName -eq 'ByParameter' )
    {
        if( $ContentType -eq 'Json' )
        {
            $Body = $Parameter | ConvertTo-Json -Depth 100
            $debugBody = $Body -replace '("API_Key": +")[^"]+','$1********'
        }
        else
        {
            $Body =
                $Parameter.Keys |
                ForEach-Object { '{0}={1}' -f [Uri]::EscapeDataString($_),[Uri]::EscapeDataString($Parameter[$_]) }
            $Body = $Body -join '&'
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

    $headers = Get-ProGetRequestHeader -Session $Session

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

    $numErrorsAtStart = $Global:Error.Count
    try
    {
        $optionalParams = @{
                                'ContentType' = $requestContentType;
                           }
        if( $PSCmdlet.ParameterSetName -in ('ByParameter', 'ByContent') )
        {
            if( $Body )
            {
                $optionalParams['Body'] = $Body
            }
            else
            {
                $optionalParams.Remove('ContentType')
            }
        }
        elseif( $PSCmdlet.ParameterSetName -eq ('ByFile') )
        {
            $optionalParams['Infile'] = $Infile
            $requestContentType = 'multipart/form-data'
        }

        if( $Session.Credential )
        {
            $optionalParams['Credential'] = $Session.Credential
        }

        $cmdName = 'Invoke-RestMethod'
        if( $Raw )
        {
            $cmdName = 'Invoke-WebRequest'
        }

        if( (Get-Command -Name $cmdName -ParameterName 'UseBasicParsing' -ErrorAction Ignore) )
        {
            $optionalParams['UseBasicParsing'] = $true
        }

        if (Get-Command -Name $cmdName -ParameterName 'AllowUnencryptedAuthentication' -ErrorAction Ignore)
        {
            $optionalParams['AllowUnencryptedAuthentication'] = $true
        }

        if( $Method -eq [Microsoft.PowerShell.Commands.WebRequestMethod]::Get -or $PSCmdlet.ShouldProcess($uri,$Method) )
        {
            & $cmdName -Method $Method -Uri $uri @optionalParams -Headers $headers |
                ForEach-Object { $_ }
        }
    }
    catch
    {
        $Global:Error.RemoveRange(0, ($Global:Error.Count - $numErrorsAtStart))
        Write-Error -ErrorRecord $_ -ErrorAction $ErrorActionPreference
    }
}