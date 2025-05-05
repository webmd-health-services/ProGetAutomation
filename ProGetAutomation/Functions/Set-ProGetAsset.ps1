function Set-ProGetAsset
{
    <#
    .SYNOPSIS
    Adds and updates assets to the ProGet asset manager.

    .DESCRIPTION
    The `Set-ProGetAsset` adds assets to a ProGet asset directory.

    Pass the name of the asset directory to the `DirectoryName` parameter.

    Pass the path to the asset in the asset directory to the `Path` parameter.

    Pass the path to the local file to upload to the `FilePath` parameter or the content (as a string) to the `Content` parameter.

    Pass the path to a `.zip` or `.tgz`/`.tar.gz` archive to the `ArchivePath` parameter to use the [Import
    Archive](https://docs.inedo.com/docs/proget/api/assets/folders/import) API to import all the contents of the archive
    to the asset folder at `Path`. If the specified folder `PAth` does not exist, it will be created.

    When importing an archive via `ArchiveFile`, by default items already present in the asset directory will not be
    overwritten. Use the `Overwrite` switch to overwrite all existing items when importing an archive.

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

        # The maximum size in bytes of the request's content to send to ProGet. The default is
        # 30 megabytes/28.6 mebibytes (the default maximum request content size in IIS).
        #
        # If a file is greater than this size, `Set-ProGetAsset` will upload the file in `MaxRequestSize` chunks, each
        # chunk sent in a separate HTTP request. Set this to the maximum allowed content size of your web server. For
        # IIS, this is configured in the system.webServer/security/requestFiltering/requestFiltering/requestLimits
        # element's `maxAllowedContentLength` attribute. In Apache, this is configured with the `LimitRequestBody`
        # directive.
        [int] $MaxRequestSize = 30000000,

        # The relative path of a file to be published as an asset.
        [Parameter(Mandatory, ParameterSetName='ByFile')]
        [String] $FilePath,

        # The relative path to an archive whose contents are imported as assets.
        [Parameter(Mandatory, ParameterSetName='ByArchive')]
        [String] $ArchivePath,

        # When importing an archive, overwrite items if they're already present in the asset directory.
        [Parameter(ParameterSetName='ByArchive')]
        [switch] $Overwrite,

        # The content to be published as an asset.
        [Parameter(Mandatory, ParameterSetName='ByContent')]
        [String] $Content,

        # The asset's content type. By default, the asset's content type will be "application/octet-stream" when
        # uploading a file with the `FilePath` parameter, or "text/plain; charset=utf-8" when uploading a string with
        # the `Content` parameter.
        [Parameter(ParameterSetName='ByFile')]
        [Parameter(ParameterSetName='ByContent')]
        [String] $ContentType
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if ($FilePath -or $ArchivePath)
    {
        $fileToUpload = $FilePath
        $action = 'upload file'

        if ($ArchivePath)
        {
            $fileToUpload = $ArchivePath
            $action = 'import archive'
        }

        if (-not (Test-Path -Path $fileToUpload))
        {
            $msg = "Could not ${action} ""${fileToUpload}"" to ProGet asset directory ""${DirectoryName}"" because " +
                   'that file does not exist.'
            Write-Error -Message $msg -ErrorAction $ErrorActionPreference
            return
        }

        if ($FilePath)
        {
            # Create a zero-byte file, otherwise ProGet responds with a 404 not found when uploading the file.
            $Content = ''
            if (-not $ContentType)
            {
                $ContentType = 'application/octet-stream'
            }
        }
    }
    else
    {
        if (-not $ContentType)
        {
            $ContentType = 'text/plain; charset=utf-8'
        }
    }

    $Path = $Path.TrimStart('/')
    $assetDirPath = "/endpoints/$([Uri]::EscapeDataString($DirectoryName))/"
    $assetPath = "${assetDirPath}content/${Path}"

    if ($ArchivePath)
    {
        $assetPath = "${assetDirPath}import/${Path}?overwrite=$($Overwrite.ToString().ToLower())"
    }

    if (-not (Test-ProGetFeed -Session $Session -Name $DirectoryName))
    {
        $msg = "Failed to create asset ""$($assetPath)"" in ProGet asset directory ""$($DirectoryName)"" because that " +
               'asset directory does not exist.'
        Write-Error -Message $msg -ErrorAction $ErrorActionPreference
        return
    }

    if ($PSCmdlet.ParameterSetName -in @('ByFile', 'ByContent'))
    {
        Invoke-ProGetRestMethod -Session $Session -Path $assetPath -Method Post -Body $Content -ContentType $ContentType

        if ($PSCmdlet.ParameterSetName -eq 'ByContent')
        {
            return
        }
    }

    # Can't use Send-ProGetAsset because multi-part uploads are not supported with the "Import Archive" (`import`)
    # endpoint (EDO-11818).
    if ($PSCmdlet.ParameterSetName -eq 'ByArchive')
    {
        Invoke-ProGetRestMethod -Session $Session `
                                -Path $assetPath `
                                -Method Post `
                                -InFile $ArchivePath
    }
    else
    {
        Send-ProGetAsset -Session $Session `
                        -AssetPath $assetPath `
                        -FilePath $FilePath `
                        -MaxRequestSize $MaxRequestSize
    }
}
