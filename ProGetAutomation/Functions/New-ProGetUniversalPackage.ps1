
function New-ProGetUniversalPackage
{
    <#
    .SYNOPSIS
    Creates a ProGet universal package file.

    .DESCRIPTION
    The `New-ProGetUniversalPackage` function creates a ProGet universal package file. The file will only contain a upack.json file. Pass the path to the file to create to the `OutFile` parameter (the file must not exist or you'll get an error). You must supply a name (with the `Name` parameter) and a version (with the `Version` parameter). Names can only contain letters, numbers, periods, underscores, and hyphens. Version must be a valid semantic version. Pass

    `New-ProGetUniversalPackage` has the following parameters that add the appropriate metadata to the package's upack.json manifest:

    * GroupName
    * Title
    * ProjectUri
    * IconUri
    * Description
    * Tag (creates the `tags` property)
    * Dependency (creates the `dependencies` property)
    * Reason (creates the `createdReason` property)
    * Author (creates the `createdBy` property)

    You can pass additional custom metadata to the `AdditionalMetadata` property. It is recommended that all custom metadata be prefixed with an underscore to prevent collision with future standard metadata.

    The `New-ProGetUniversalPackage` function always adds two additional pieces of metadata:
    
    * `createdDate`, the UTC date/time this function gets called
    * `createdUsing`, a string that identifies the ProGetAutomation module as the tool used; it includes the module's version, the PowerShell version, and, if available, the PowerShell edition.

    A `IO.FileInfo` object is returned for the just-created package.

    The `Zip` PowerShell module is used to create the ZIP archive and add the upack.json file to it.

    By default, optimal compression is used. You can customize your compression level with the `CompressionLevel` parameter.

    See the [upack.json Manifest Specification page](https://inedo.com/support/documentation/upack/universal-packages/metacontent-guidance/manifest-specification) for more information about the format and contents of the upack.json file.

    Once you've created the package, you can then add additional files to it with the `Add-ProGetUniversalPackage` function.

    .EXAMPLE
    New-ProGetUniversalPackage -OutFile 'package.upack' -Version '0.0.0' -Name 'ProGetAutomation'

    Demonstrates how to create a minimal upack package.

    .EXAMPLE
    New-ProGetUniversalPackage -OutFile 'package.upack' -Version '0.0.0' -Name 'ProGetAutomation' -GroupName 'WHS/PowerShell' -Title 'ProGet Automation' -ProjectUri 'https://github.com/webmd-health-services/ProGetAutomation' -IconUri 'https://github.com/webmd-health-services/ProGetAutomation/icon.png' -Description 'A PowerShell module for automationg ProGet.' -Tag @( 'powershell', 'module', 'inedo', 'proget' ) -Dependency @( 'zip' ) -Reason 'Because the world needs more PowerShell!' -Author 'WebMD Health Services' 

    Demonstrates how to create a upack package with all required and optional metadata. (The ProGetAutomation package doesn't have any dependencies. The example shows one for illustrative purposes only.)

    .EXAMPLE
    New-ProGetUniversalPackage -OutFile 'package.upack' -Version '0.0.0' -Name 'ProGetAutomation' -AdditionalMetadata @{ '_whs' = @{ 'fubar' = 'snafu' } }

    Demonstrates how to add custom metadata to your package.

    .EXAMPLE
    New-ProGetUniversalPackage -OutFile 'package.upack' -Version '0.0.0' -Name 'ProGetAutomation' -CompressionLevel Fastest

    Demonstrates how to change the compression level of the package.
    #>
    [CmdletBinding()]
    [OutputType([IO.FileInfo])]
    param(
        [Parameter(Mandatory)]
        [string]
        # Path to the package. The package is created here. The filename should have a .upack extension.
        $OutFile,

        [Parameter(Mandatory)]
        [string]
        # The version of the package. Semantic Version 2 supported.
        $Version,

        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9._-]+$')]
        [string]
        # The name of the package. Must only contain letters, numbers, periods, underscores or hyphens.
        $Name,

        [ValidatePattern('^[A-Za-z0-9._/-]+$')]
        [ValidatePattern('^[^/]')]
        [ValidatePattern('[^/]$')]
        [string]
        # The group name of the package. Must only contain letters, numbers, periods, underscores, forward slashes, or hyphens. Must not begin or end with forward slashes.
        $GroupName,

        [ValidateLength(1,50)]
        [string]
        # The package's title/display name. Any characters are allowed. Can't be longer than 50 characters.
        $Title,

        [uri]
        # The URI to the project.
        $ProjectUri,

        [uri]
        # The URI to the projet/package's icon. The icon may be in the package itself. If it is, pass `package://path/to/icon`.
        $IconUri,

        [string]
        # A full description of the package. Formatted as Markdown in the ProGet UI.
        $Description,

        [string[]]
        [ValidatePattern('^[A-Za-z0-9._-]+$')]
        # An array of tags. Each tag must only contain letters, numbers, periods, underscores, and hyphens.
        $Tag,

        [string[]]
        # A list of dependencies as package names. Must be formatted like:
        # 
        # * «group»/«package-name»
        # * «group»/«package-name»:«version»
        # * «group»/«package-name»:«version»:«sha-hash»
        $Dependency,

        [string]
        # The reason the package is getting created.
        $Reason,

        [string]
        # The author of the package.
        $Author,

        [hashtable]
        # Any additional metadata for the package. It is recommended that you prefix custom metadata with an underscore to prevent possible collisions with future system metadata. 
        #
        # If you provide a parameter and duplicate that parameter's metadata in this hashtable, the parameter value takes precedence.
        #
        # 
        $AdditionalMetadata = @{ },

        [IO.Compression.CompressionLevel]
        # The compression level to use. The default is `Optimal`. Other values are `Fastest` (larger file, created faster) or `None` (nothing is compressed).
        $CompressionLevel = [IO.Compression.CompressionLevel]::Optimal
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $tempDir = Join-Path -Path $env:TEMP -ChildPath ('{0}.{1}' -f ($OutFile | Split-Path -Leaf),([IO.Path]::GetRandomFileName()))
    New-Item -Path $tempDir -ItemType 'Directory' | Out-Null

    try
    {
        $upackJsonPath = Join-Path -Path $tempDir -ChildPath 'upack.json'

        [hashtable]$upackJson = $AdditionalMetadata.Clone()

        $upackJson['name'] =  $Name;
        $upackJson['version'] = $Version;

        if( -not $upackJson.ContainsKey('createdUsing') )
        {
            $psEdition = ''
            if( $PSVersionTable.ContainsKey('PSEdition') )
            {
                $psEdition = '; {0}' -f $PSVersionTable['PSEdition']
            }
            $upackJson['createdUsing'] = 'ProGetAutomation/{0} (PowerShell {1}{2})' -f (Get-Module -Name 'ProGetAutomation').Version,$PSVersionTable['PSVersion'],$psEdition
        }

        if( -not $upackJson.ContainsKey('createdDate') )
        {
            $upackJson['createdDate'] = (Get-Date).ToUniversalTime().ToString('O')
        }

        $parameterToMetadataMap = @{
                                        'GroupName' = 'groupName';
                                        'Title' = 'title';
                                        'ProjectUri' = 'projectUri';
                                        'IconUri' = 'iconUri';
                                        'Description' = 'description';
                                        'Tag' = 'tags';
                                        'Dependency' = 'dependencies';
                                        'Reason' = 'createdReason';
                                        'Author' = 'createdBy';
                                    }
        foreach( $parameterName in $parameterToMetadataMap.Keys )
        {
            if( -not $PSBoundParameters.ContainsKey($parameterName) )
            {
                continue
            }
        
            $metadataName = $parameterToMetadataMap[$parameterName]
            $upackJson[$metadataName] = $PSBoundParameters[$parameterName]
        }

        $upackJson | 
            ForEach-Object { [pscustomobject]$_ } |
            ConvertTo-Json -Depth 50 | 
            Set-Content -Path $upackJsonPath

        $archive = New-ZipArchive -Path $OutFile -CompressionLevel $CompressionLevel
        $upackJsonPath | Add-ZipArchiveEntry -ZipArchivePath $archive.FullName -BasePath $tempDir -CompressionLevel $CompressionLevel
        $archive
    }
    finally
    {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction Ignore
    }
}