#
# Module manifest for module 'ProGetAutomation'
#
# Generated by: Lifecycle Services
#
# Generated on: 3/1/2017
#

@{

    # Script module or binary module file associated with this manifest.
    RootModule = 'ProGetAutomation.psm1'

    # Version number of this module.
    ModuleVersion = '2.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @( 'Desktop', 'Core' )

    # ID used to uniquely identify this module
    GUID = 'b7139a9b-572b-48cf-b08c-82a96cdab454'

    # Author of this module
    Author = 'WebMD Health Services'

    # Company or vendor of this module
    CompanyName = 'WebMD Health Services'

    # Copyright statement for this module
    Copyright = '(c) 2017 - 2018 WebMD Health Services. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'The ProGetAutomation module is used to automate Inedo''s ProGet, a universal package manager. It can host your own NuGet, Docker, PowerShell, Ruby Gems, Visual Studio Extensions, Maven, NPM, Bower, and Chocolatey repositories. It has its own proprietary universal package repositories.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Name of the Windows PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the Windows PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module
    # DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module
    # CLRVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    # RequiredModules = @()

    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies = @( )

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess = @(
                            'Formats\Inedo.ProGet.Feed.ps1xml',
                            'Formats\Inedo.ProGet.Native.Feed.ps1xml',
                            'Formats\Inedo.ProGet.PackageInfo.ps1xml'
                        )

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    # NestedModules = @()

    # Functions to export from this module
    FunctionsToExport = @(
                            'Add-ProGetUniversalPackageFile',
                            'Get-ProGetAsset',
                            'Get-ProGetAssetContent',
                            'Get-ProGetFeed',
                            'Get-ProGetUniversalPackage',
                            'Invoke-ProGetNativeApiMethod',
                            'Invoke-ProGetRestMethod',
                            'New-ProGetFeed',
                            'New-ProGetSession',
                            'New-ProGetUniversalPackage',
                            'Publish-ProGetUniversalPackage',
                            'Read-ProGetUniversalPackageFile',
                            'Remove-ProGetAsset',
                            'Remove-ProGetFeed',
                            'Remove-ProGetUniversalPackage',
                            'Set-ProGetAsset',
                            'Test-ProGetFeed'
                         )

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    # DSC resources to export from this module
    # DscResourcesToExport = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    # FileList = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @( 'proget', 'inedo', 'devops', 'pipeline', 'package' )

            # A URL to the license for this module.
            LicenseUri = 'https://www.apache.org/licenses/LICENSE-2.0'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/webmd-health-services/ProGetAutomation'

            # A URL to an icon representing this module.
            # IconUri = ''

            # Any prerelease information.
            Prerelease = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
* Upgraded to support ProGet 5.3.32.
'@

        } # End of PSData hashtable

    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''

}
