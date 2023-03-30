function Set-ProGetAsset
{
    <#
    .SYNOPSIS
    Adds and updates assets to the ProGet asset manager.

    .DESCRIPTION
    The `Set-ProGetAsset` adds assets to a ProGet asset directory. Pass the name of the asset directory to the
    `DirectoryName` parameter. Pass the path to the asset in the asset directory to the `Path` parameter. Pass the path
    to the local file to upload to the `FilePath` parameter or the content (as a string) to the `Content` parameter.


    .EXAMPLE
    Set-ProGetAsset -Session $session -DirectoryName 'assetDirectory' -Path 'subdir/exampleAsset.txt' -FilePath 'path/to/file.txt'

    Example of publishing local file `path/to/file.txt` to ProGet in the `assetDirectory/subdir` folder as
    `exampleAsset.txt`.

    .EXAMPLE
    Set-ProGetAsset -Session $session -Directory 'assetDirectory' -Path 'exampleAsset.txt' -Content $bodyContent

    Example of publishing content contained in the $bodyContent variable to ProGet in the `assetDirectory` folder.
    #>
    [CmdletBinding()]
    param(
        # A session object to the ProGet instance to use. Use the `New-ProGetSession` function to create
        # a session object.
        [Parameter(Mandatory)]
        [Object] $Session,

        # The name of an existing asset directory. The function will escape any URL-sensitive characters.
        [Parameter(Mandatory)]
        [String] $DirectoryName,

        # The path where the asset will be published. Any directories that do not exist will be created automatically.
        # This is treated as a URL path, so you must escape any URL-sensitive characters.
        [Parameter(Mandatory)]
        [String] $Path,

        # The relative path of a file to be published as an asset.
        [Parameter(Mandatory, ParameterSetName='ByFile')]
        [String] $FilePath,

        # The maximum size in bytes of the request's content to send to ProGet. The default is
        # 30 megabytes/28.6 mebibytes (the default maximum request content size in IIS).
        #
        # If a file is greater than this size, `Set-ProGetAsset` will upload the file in `MaxRequestSize` chunks, each
        # chunk sent in a separate HTTP request. Set this to the maximum allowed content size of your web server. For
        # IIS, this is configured in the system.webServer/security/requestFiltering/requestFiltering/requestLimits
        # element's `maxAllowedContentLength` attribute. In Apache, this is configured with the `LimitRequestBody`
        # directive.
        [int] $MaxRequestSize = 30000000,

        # The content to be published as an asset.
        [Parameter(Mandatory, ParameterSetName='ByContent')]
        [String] $Content
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if ($FilePath)
    {
        if (-not (Test-Path -Path $FilePath))
        {
            $msg = "Could not upload file ""$($FilePath)"" to ProGet asset directory ""$($DirectoryName)"" because " +
                   'that file does not exist.'
            Write-Error -Message $msg -ErrorAction $ErrorActionPreference
            return
        }

        # Create a zero-byte file, otherwise ProGet responds with a 404 not found when uploading the file.
        $Content = ''
    }

    $assetPath = "/endpoints/$([Uri]::EscapeDataString($DirectoryName))/content/$($Path.TrimStart('/'))"

    if (-not (Test-ProGetFeed -Session $Session -Name $DirectoryName -Type Asset))
    {
        $msg = "Failed to upload file ""$($FilePath)"" to ProGet asset directory ""$($DirectoryName)"" because that " +
               'asset directory does not exist.'
        Write-Error -Message $msg -ErrorAction $ErrorActionPreference
        return
    }

    Invoke-ProGetRestMethod -Session $Session -Path $assetPath -Method Post -Body $Content

    if ($FilePath)
    {
        Send-ProGetAsset -Session $Session `
                         -AssetPath $assetPath `
                         -FilePath $FilePath `
                         -MaxRequestSize $MaxRequestSize
    }
}
