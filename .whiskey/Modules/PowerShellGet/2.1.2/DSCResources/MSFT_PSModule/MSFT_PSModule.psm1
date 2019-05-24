#
# Copyright (c) Microsoft Corporation.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

$resourceModuleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent

# Import localization helper functions.
$helperName = 'PowerShellGet.LocalizationHelper'
$dscResourcesFolderFilePath = Join-Path -Path $resourceModuleRoot -ChildPath "Modules\$helperName\$helperName.psm1"
Import-Module -Name $dscResourcesFolderFilePath

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_PSModule' -ScriptRoot $PSScriptRoot

# Import resource helper functions.
$helperName = 'PowerShellGet.ResourceHelper'
$dscResourcesFolderFilePath = Join-Path -Path $resourceModuleRoot -ChildPath "Modules\$helperName\$helperName.psm1"
Import-Module -Name $dscResourcesFolderFilePath

<#
    .SYNOPSIS
        This DSC resource provides a mechanism to download PowerShell modules from the PowerShell
        Gallery and install it on your computer.

        Get-TargetResource returns the current state of the resource.

    .PARAMETER Name
        Specifies the name of the PowerShell module to be installed or uninstalled.

    .PARAMETER Repository
        Specifies the name of the module source repository where the module can be found.

    .PARAMETER RequiredVersion
        Provides the version of the module you want to install or uninstall.

    .PARAMETER MaximumVersion
        Provides the maximum version of the module you want to install or uninstall.

    .PARAMETER MinimumVersion
        Provides the minimum version of the module you want to install or uninstall.

    .PARAMETER Force
        Forces the installation of modules. If a module of the same name and version already exists on the computer,
        this parameter overwrites the existing module with one of the same name that was found by the command.

    .PARAMETER AllowClobber
        Allows the installation of modules regardless of if other existing module on the computer have cmdlets
        of the same name.

    .PARAMETER SkipPublisherCheck
        Allows the installation of modules that have not been catalog signed.
#>
function Get-TargetResource {
    <#
        These suppressions are added because this repository have other Visual Studio Code workspace
        settings than those in DscResource.Tests DSC test framework.
        Only those suppression that contradict this repository guideline is added here.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-ForEachStatement', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-FunctionBlockBraces', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-IfStatement', '')]
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter()]
        [System.String]
        $Repository = 'PSGallery',

        [Parameter()]
        [System.String]
        $RequiredVersion,

        [Parameter()]
        [System.String]
        $MaximumVersion,

        [Parameter()]
        [System.String]
        $MinimumVersion,

        [Parameter()]
        [System.Boolean]
        $Force,

        [Parameter()]
        [System.Boolean]
        $AllowClobber,

        [Parameter()]
        [System.Boolean]
        $SkipPublisherCheck
    )

    $returnValue = @{
        Ensure             = 'Absent'
        Name               = $Name
        Repository         = $Repository
        Description        = $null
        Guid               = $null
        ModuleBase         = $null
        ModuleType         = $null
        Author             = $null
        InstalledVersion   = $null
        RequiredVersion    = $RequiredVersion
        MinimumVersion     = $MinimumVersion
        MaximumVersion     = $MaximumVersion
        Force              = $Force
        AllowClobber       = $AllowClobber
        SkipPublisherCheck = $SkipPublisherCheck
        InstallationPolicy = $null
    }

    Write-Verbose -Message ($localizedData.GetTargetResourceMessage -f $Name)

    $extractedArguments = New-SplatParameterHashTable -FunctionBoundParameters $PSBoundParameters `
        -ArgumentNames ('Name', 'Repository', 'MinimumVersion', 'MaximumVersion', 'RequiredVersion')

    # Get the module with the right version and repository properties.
    $modules = Get-RightModule @extractedArguments -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

    # If the module is found, the count > 0
    if ($modules.Count -gt 0) {
        Write-Verbose -Message ($localizedData.ModuleFound -f $Name)

        # Find a module with the latest version and return its properties.
        $latestModule = $modules[0]

        foreach ($module in $modules) {
            if ($module.Version -gt $latestModule.Version) {
                $latestModule = $module
            }
        }

        # Check if the repository matches.
        $repositoryName = Get-ModuleRepositoryName -Module $latestModule -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

        $installationPolicy = Get-InstallationPolicy -RepositoryName $repositoryName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        if ($installationPolicy) {
            $installationPolicyReturnValue = 'Trusted'
        }
        else {
            $installationPolicyReturnValue = 'Untrusted'
        }

        $returnValue.Ensure = 'Present'
        $returnValue.Repository = $repositoryName
        $returnValue.Description = $latestModule.Description
        $returnValue.Guid = $latestModule.Guid
        $returnValue.ModuleBase = $latestModule.ModuleBase
        $returnValue.ModuleType = $latestModule.ModuleType
        $returnValue.Author = $latestModule.Author
        $returnValue.InstalledVersion = $latestModule.Version
        $returnValue.InstallationPolicy = $installationPolicyReturnValue
    }
    else {
        Write-Verbose -Message ($localizedData.ModuleNotFound -f $Name)
    }

    return $returnValue
}

<#
    .SYNOPSIS
        This DSC resource provides a mechanism to download PowerShell modules from the PowerShell
        Gallery and install it on your computer.

        Test-TargetResource validates whether the resource is currently in the desired state.

    .PARAMETER Ensure
        Determines whether the module to be installed or uninstalled.

    .PARAMETER Name
        Specifies the name of the PowerShell module to be installed or uninstalled.

    .PARAMETER Repository
        Specifies the name of the module source repository where the module can be found.

    .PARAMETER InstallationPolicy
        Determines whether you trust the source repository where the module resides.

    .PARAMETER RequiredVersion
        Provides the version of the module you want to install or uninstall.

    .PARAMETER MaximumVersion
        Provides the maximum version of the module you want to install or uninstall.

    .PARAMETER MinimumVersion
        Provides the minimum version of the module you want to install or uninstall.

    .PARAMETER Force
        Forces the installation of modules. If a module of the same name and version already exists on the computer,
        this parameter overwrites the existing module with one of the same name that was found by the command.

    .PARAMETER AllowClobber
        Allows the installation of modules regardless of if other existing module on the computer have cmdlets
        of the same name.

    .PARAMETER SkipPublisherCheck
        Allows the installation of modules that have not been catalog signed.
#>
function Test-TargetResource {
    <#
        These suppressions are added because this repository have other Visual Studio Code workspace
        settings than those in DscResource.Tests DSC test framework.
        Only those suppression that contradict this repository guideline is added here.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-FunctionBlockBraces', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-IfStatement', '')]
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter()]
        [System.String]
        $Repository = 'PSGallery',

        [Parameter()]
        [ValidateSet('Trusted', 'Untrusted')]
        [System.String]
        $InstallationPolicy = 'Untrusted',

        [Parameter()]
        [System.String]
        $RequiredVersion,

        [Parameter()]
        [System.String]
        $MaximumVersion,

        [Parameter()]
        [System.String]
        $MinimumVersion,

        [Parameter()]
        [System.Boolean]
        $Force,

        [Parameter()]
        [System.Boolean]
        $AllowClobber,

        [Parameter()]
        [System.Boolean]
        $SkipPublisherCheck
    )

    Write-Verbose -Message ($localizedData.TestTargetResourceMessage -f $Name)

    $extractedArguments = New-SplatParameterHashTable -FunctionBoundParameters $PSBoundParameters `
        -ArgumentNames ('Name', 'Repository', 'MinimumVersion', 'MaximumVersion', 'RequiredVersion')

    $status = Get-TargetResource @extractedArguments

    # The ensure returned from Get-TargetResource is not equal to the desired $Ensure.
    if ($status.Ensure -ieq $Ensure) {
        Write-Verbose -Message ($localizedData.InDesiredState -f $Name)
        return $true
    }
    else {
        Write-Verbose -Message ($localizedData.NotInDesiredState -f $Name)
        return $false
    }
}

<#
    .SYNOPSIS
        This DSC resource provides a mechanism to download PowerShell modules from the PowerShell
        Gallery and install it on your computer.

        Set-TargetResource sets the resource to the desired state. "Make it so".

    .PARAMETER Ensure
        Determines whether the module to be installed or uninstalled.

    .PARAMETER Name
        Specifies the name of the PowerShell module to be installed or uninstalled.

    .PARAMETER Repository
        Specifies the name of the module source repository where the module can be found.

    .PARAMETER InstallationPolicy
        Determines whether you trust the source repository where the module resides.

    .PARAMETER RequiredVersion
        Provides the version of the module you want to install or uninstall.

    .PARAMETER MaximumVersion
        Provides the maximum version of the module you want to install or uninstall.

    .PARAMETER MinimumVersion
        Provides the minimum version of the module you want to install or uninstall.

    .PARAMETER Force
        Forces the installation of modules. If a module of the same name and version already exists on the computer,
        this parameter overwrites the existing module with one of the same name that was found by the command.

    .PARAMETER AllowClobber
        Allows the installation of modules regardless of if other existing module on the computer have cmdlets
        of the same name.

    .PARAMETER SkipPublisherCheck
        Allows the installation of modules that have not been catalog signed.
#>
function Set-TargetResource {
    <#
        These suppressions are added because this repository have other Visual Studio Code workspace
        settings than those in DscResource.Tests DSC test framework.
        Only those suppression that contradict this repository guideline is added here.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-ForEachStatement', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-FunctionBlockBraces', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-IfStatement', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-TryStatement', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-CatchClause', '')]
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter()]
        [System.String]
        $Repository = 'PSGallery',

        [Parameter()]
        [ValidateSet('Trusted', 'Untrusted')]
        [System.String]
        $InstallationPolicy = 'Untrusted',

        [Parameter()]
        [System.String]
        $RequiredVersion,

        [Parameter()]
        [System.String]
        $MaximumVersion,

        [Parameter()]
        [System.String]
        $MinimumVersion,

        [Parameter()]
        [System.Boolean]
        $Force,

        [Parameter()]
        [System.Boolean]
        $AllowClobber,

        [Parameter()]
        [System.Boolean]
        $SkipPublisherCheck
    )

    # Validate the repository argument
    if ($PSBoundParameters.ContainsKey('Repository')) {
        Test-ParameterValue -Value $Repository -Type 'PackageSource' -ProviderName 'PowerShellGet' -Verbose
    }

    if ($Ensure -ieq 'Present') {
        # Version check
        $extractedArguments = New-SplatParameterHashTable -FunctionBoundParameters $PSBoundParameters `
            -ArgumentNames ('MinimumVersion', 'MaximumVersion', 'RequiredVersion')

        Test-VersionParameter @extractedArguments

        try {
            $extractedArguments = New-SplatParameterHashTable -FunctionBoundParameters $PSBoundParameters `
                -ArgumentNames ('Name', 'Repository', 'MinimumVersion', 'MaximumVersion', 'RequiredVersion')

            Write-Verbose -Message ($localizedData.StartFindModule -f $Name)

            $modules = Find-Module @extractedArguments -ErrorVariable ev
        }
        catch {
            $errorMessage = $script:localizedData.ModuleNotFoundInRepository -f $Name
            New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
        }

        $trusted = $null
        $moduleFound = $null

        foreach ($m in $modules) {
            # Check for the installation policy.
            $trusted = Get-InstallationPolicy -RepositoryName $m.Repository -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

            # Stop the loop if found a trusted repository.
            if ($trusted) {
                $moduleFound = $m
                break;
            }
        }

        try {
            # The repository is trusted, so we install it.
            if ($trusted) {
                Write-Verbose -Message ($localizedData.StartInstallModule -f $Name, $moduleFound.Version.toString(), $moduleFound.Repository)

                # Extract the installation options.
                $extractedSwitches = New-SplatParameterHashTable -FunctionBoundParameters $PSBoundParameters -ArgumentNames ('Force', 'AllowClobber', 'SkipPublisherCheck')

                $moduleFound | Install-Module @extractedSwitches
            }
            # The repository is untrusted but user's installation policy is trusted, so we install it with a warning.
            elseif ($InstallationPolicy -ieq 'Trusted') {
                Write-Warning -Message ($localizedData.InstallationPolicyWarning -f $Name, $modules[0].Repository, $InstallationPolicy)

                # Extract installation options (Force implied by InstallationPolicy).
                $extractedSwitches = New-SplatParameterHashTable -FunctionBoundParameters $PSBoundParameters -ArgumentNames ('AllowClobber', 'SkipPublisherCheck')

                # If all the repositories are untrusted, we choose the first one.
                $modules[0] | Install-Module @extractedSwitches -Force
            }
            # Both user and repository is untrusted
            else {
                $errorMessage = $script:localizedData.InstallationPolicyFailed -f $InstallationPolicy, 'Untrusted'
                New-InvalidOperationException -Message $errorMessage
            }

            Write-Verbose -Message ($localizedData.InstalledSuccess -f $Name)
        }
        catch {
            $errorMessage = $script:localizedData.FailToInstall -f $Name
            New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
        }
    }
    # Ensure=Absent
    else {

        $extractedArguments = New-SplatParameterHashTable -FunctionBoundParameters $PSBoundParameters `
            -ArgumentNames ('Name', 'Repository', 'MinimumVersion', 'MaximumVersion', 'RequiredVersion')

        # Get the module with the right version and repository properties.
        $modules = Get-RightModule @extractedArguments

        if (-not $modules) {
            $errorMessage = $script:localizedData.ModuleWithRightPropertyNotFound -f $Name
            New-InvalidOperationException -Message $errorMessage
        }

        foreach ($module in $modules) {
            # Get the path where the module is installed.
            $path = $module.ModuleBase

            Write-Verbose -Message ($localizedData.StartUnInstallModule -f $Name)

            try {
                <#
                    There is no Uninstall-Module cmdlet for Windows PowerShell 4.0,
                    so we will remove the ModuleBase folder as an uninstall operation.
                #>
                Microsoft.PowerShell.Management\Remove-Item -Path $path -Force -Recurse

                Write-Verbose -Message ($localizedData.UnInstalledSuccess -f $module.Name)
            }
            catch {
                $errorMessage = $script:localizedData.FailToUninstall -f $module.Name
                New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
            }
        } # foreach
    } # Ensure=Absent
}

<#
    .SYNOPSIS
        This is a helper function. It returns the modules that meet the specified versions and the repository requirements.

    .PARAMETER Name
        Specifies the name of the PowerShell module.

    .PARAMETER RequiredVersion
        Provides the version of the module you want to install or uninstall.

    .PARAMETER MaximumVersion
        Provides the maximum version of the module you want to install or uninstall.

    .PARAMETER MinimumVersion
        Provides the minimum version of the module you want to install or uninstall.

    .PARAMETER Repository
        Specifies the name of the module source repository where the module can be found.
#>
function Get-RightModule {
    <#
        These suppressions are added because this repository have other Visual Studio Code workspace
        settings than those in DscResource.Tests DSC test framework.
        Only those suppression that contradict this repository guideline is added here.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-ForEachStatement', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-FunctionBlockBraces', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-IfStatement', '')]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,

        [Parameter()]
        [System.String]
        $RequiredVersion,

        [Parameter()]
        [System.String]
        $MinimumVersion,

        [Parameter()]
        [System.String]
        $MaximumVersion,

        [Parameter()]
        [System.String]
        $Repository
    )

    Write-Verbose -Message ($localizedData.StartGetModule -f $($Name))

    $modules = Microsoft.PowerShell.Core\Get-Module -Name $Name -ListAvailable -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

    if (-not $modules) {
        return $null
    }

    <#
        As Get-Module does not take RequiredVersion, MinimumVersion, MaximumVersion, or Repository,
        below we need to check whether the modules are containing the right version and repository
        location.
    #>

    $extractedArguments = New-SplatParameterHashTable -FunctionBoundParameters $PSBoundParameters `
        -ArgumentNames ('MaximumVersion', 'MinimumVersion', 'RequiredVersion')
    $returnVal = @()

    foreach ($m in $modules) {
        $versionMatch = $false
        $installedVersion = $m.Version

        # Case 1 - a user provides none of RequiredVersion, MinimumVersion, MaximumVersion
        if ($extractedArguments.Count -eq 0) {
            $versionMatch = $true
        }

        # Case 2 - a user provides RequiredVersion
        elseif ($extractedArguments.ContainsKey('RequiredVersion')) {
            # Check if it matches with the installed version
            $versionMatch = ($installedVersion -eq [System.Version] $RequiredVersion)
        }
        else {

            # Case 3 - a user provides MinimumVersion
            if ($extractedArguments.ContainsKey('MinimumVersion')) {
                $versionMatch = ($installedVersion -ge [System.Version] $extractedArguments['MinimumVersion'])
            }

            # Case 4 - a user provides MaximumVersion
            if ($extractedArguments.ContainsKey('MaximumVersion')) {
                $isLessThanMax = ($installedVersion -le [System.Version] $extractedArguments['MaximumVersion'])

                if ($extractedArguments.ContainsKey('MinimumVersion')) {
                    $versionMatch = $versionMatch -and $isLessThanMax
                }
                else {
                    $versionMatch = $isLessThanMax
                }
            }

            # Case 5 - Both MinimumVersion and MaximumVersion are provided. It's covered by the above.
            # Do not return $false yet to allow the foreach to continue
            if (-not $versionMatch) {
                Write-Verbose -Message ($localizedData.VersionMismatch -f $Name, $installedVersion)
                $versionMatch = $false
            }
        }

        # Case 6 - Version matches but need to check if the module is from the right repository.
        if ($versionMatch) {
            # A user does not provide Repository, we are good
            if (-not $PSBoundParameters.ContainsKey('Repository')) {
                Write-Verbose -Message ($localizedData.ModuleFound -f "$Name $installedVersion")
                $returnVal += $m
            }
            else {
                # Check if the Repository matches
                $sourceName = Get-ModuleRepositoryName -Module $m

                if ($Repository -ieq $sourceName) {
                    Write-Verbose -Message ($localizedData.ModuleFound -f "$Name $installedVersion")
                    $returnVal += $m
                }
                else {
                    Write-Verbose -Message ($localizedData.RepositoryMismatch -f $($Name), $($sourceName))
                }
            }
        }
    } # foreach

    return $returnVal
}

<#
    .SYNOPSIS
        This is a helper function that returns the module's repository name.

    .PARAMETER Module
        Specifies the name of the PowerShell module.
#>
function Get-ModuleRepositoryName {
    <#
        These suppressions are added because this repository have other Visual Studio Code workspace
        settings than those in DscResource.Tests DSC test framework.
        Only those suppression that contradict this repository guideline is added here.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-FunctionBlockBraces', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-IfStatement', '')]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Object]
        $Module
    )

    <#
        RepositorySourceLocation property is supported in PS V5 only. To work with the earlier
        PowerShell version, we need to do a different way. PSGetModuleInfo.xml exists for any
        PowerShell modules downloaded through PSModule provider.
    #>
    $psGetModuleInfoFileName = 'PSGetModuleInfo.xml'
    $psGetModuleInfoPath = Microsoft.PowerShell.Management\Join-Path -Path $Module.ModuleBase -ChildPath $psGetModuleInfoFileName

    Write-Verbose -Message ($localizedData.FoundModulePath -f $psGetModuleInfoPath)

    if (Microsoft.PowerShell.Management\Test-path -Path $psGetModuleInfoPath) {
        $psGetModuleInfo = Microsoft.PowerShell.Utility\Import-Clixml -Path $psGetModuleInfoPath

        return $psGetModuleInfo.Repository
    }
}

# SIG # Begin signature block
# MIIjhgYJKoZIhvcNAQcCoIIjdzCCI3MCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDAbeq5K5OtDl/r
# ebabM/3kdlq+4jk4fgTUeuFioGB3+aCCDYEwggX/MIID56ADAgECAhMzAAABA14l
# HJkfox64AAAAAAEDMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMTgwNzEyMjAwODQ4WhcNMTkwNzI2MjAwODQ4WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDRlHY25oarNv5p+UZ8i4hQy5Bwf7BVqSQdfjnnBZ8PrHuXss5zCvvUmyRcFrU5
# 3Rt+M2wR/Dsm85iqXVNrqsPsE7jS789Xf8xly69NLjKxVitONAeJ/mkhvT5E+94S
# nYW/fHaGfXKxdpth5opkTEbOttU6jHeTd2chnLZaBl5HhvU80QnKDT3NsumhUHjR
# hIjiATwi/K+WCMxdmcDt66VamJL1yEBOanOv3uN0etNfRpe84mcod5mswQ4xFo8A
# DwH+S15UD8rEZT8K46NG2/YsAzoZvmgFFpzmfzS/p4eNZTkmyWPU78XdvSX+/Sj0
# NIZ5rCrVXzCRO+QUauuxygQjAgMBAAGjggF+MIIBejAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUR77Ay+GmP/1l1jjyA123r3f3QP8w
# UAYDVR0RBEkwR6RFMEMxKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1
# ZXJ0byBSaWNvMRYwFAYDVQQFEw0yMzAwMTIrNDM3OTY1MB8GA1UdIwQYMBaAFEhu
# ZOVQBdOCqhc3NyK1bajKdQKVMFQGA1UdHwRNMEswSaBHoEWGQ2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY0NvZFNpZ1BDQTIwMTFfMjAxMS0w
# Ny0wOC5jcmwwYQYIKwYBBQUHAQEEVTBTMFEGCCsGAQUFBzAChkVodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY0NvZFNpZ1BDQTIwMTFfMjAx
# MS0wNy0wOC5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAgEAn/XJ
# Uw0/DSbsokTYDdGfY5YGSz8eXMUzo6TDbK8fwAG662XsnjMQD6esW9S9kGEX5zHn
# wya0rPUn00iThoj+EjWRZCLRay07qCwVlCnSN5bmNf8MzsgGFhaeJLHiOfluDnjY
# DBu2KWAndjQkm925l3XLATutghIWIoCJFYS7mFAgsBcmhkmvzn1FFUM0ls+BXBgs
# 1JPyZ6vic8g9o838Mh5gHOmwGzD7LLsHLpaEk0UoVFzNlv2g24HYtjDKQ7HzSMCy
# RhxdXnYqWJ/U7vL0+khMtWGLsIxB6aq4nZD0/2pCD7k+6Q7slPyNgLt44yOneFuy
# bR/5WcF9ttE5yXnggxxgCto9sNHtNr9FB+kbNm7lPTsFA6fUpyUSj+Z2oxOzRVpD
# MYLa2ISuubAfdfX2HX1RETcn6LU1hHH3V6qu+olxyZjSnlpkdr6Mw30VapHxFPTy
# 2TUxuNty+rR1yIibar+YRcdmstf/zpKQdeTr5obSyBvbJ8BblW9Jb1hdaSreU0v4
# 6Mp79mwV+QMZDxGFqk+av6pX3WDG9XEg9FGomsrp0es0Rz11+iLsVT9qGTlrEOla
# P470I3gwsvKmOMs1jaqYWSRAuDpnpAdfoP7YO0kT+wzh7Qttg1DO8H8+4NkI6Iwh
# SkHC3uuOW+4Dwx1ubuZUNWZncnwa6lL2IsRyP64wggd6MIIFYqADAgECAgphDpDS
# AAAAAAADMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMTAeFw0xMTA3MDgyMDU5MDlaFw0yNjA3MDgyMTA5MDla
# MH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMT
# H01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCr8PpyEBwurdhuqoIQTTS68rZYIZ9CGypr6VpQqrgG
# OBoESbp/wwwe3TdrxhLYC/A4wpkGsMg51QEUMULTiQ15ZId+lGAkbK+eSZzpaF7S
# 35tTsgosw6/ZqSuuegmv15ZZymAaBelmdugyUiYSL+erCFDPs0S3XdjELgN1q2jz
# y23zOlyhFvRGuuA4ZKxuZDV4pqBjDy3TQJP4494HDdVceaVJKecNvqATd76UPe/7
# 4ytaEB9NViiienLgEjq3SV7Y7e1DkYPZe7J7hhvZPrGMXeiJT4Qa8qEvWeSQOy2u
# M1jFtz7+MtOzAz2xsq+SOH7SnYAs9U5WkSE1JcM5bmR/U7qcD60ZI4TL9LoDho33
# X/DQUr+MlIe8wCF0JV8YKLbMJyg4JZg5SjbPfLGSrhwjp6lm7GEfauEoSZ1fiOIl
# XdMhSz5SxLVXPyQD8NF6Wy/VI+NwXQ9RRnez+ADhvKwCgl/bwBWzvRvUVUvnOaEP
# 6SNJvBi4RHxF5MHDcnrgcuck379GmcXvwhxX24ON7E1JMKerjt/sW5+v/N2wZuLB
# l4F77dbtS+dJKacTKKanfWeA5opieF+yL4TXV5xcv3coKPHtbcMojyyPQDdPweGF
# RInECUzF1KVDL3SV9274eCBYLBNdYJWaPk8zhNqwiBfenk70lrC8RqBsmNLg1oiM
# CwIDAQABo4IB7TCCAekwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFEhuZOVQ
# BdOCqhc3NyK1bajKdQKVMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1Ud
# DwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFHItOgIxkEO5FAVO
# 4eqnxzHRI4k0MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwubWljcm9zb2Z0
# LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcmwwXgYIKwYBBQUHAQEEUjBQME4GCCsGAQUFBzAChkJodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcnQwgZ8GA1UdIASBlzCBlDCBkQYJKwYBBAGCNy4DMIGDMD8GCCsGAQUFBwIB
# FjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2RvY3MvcHJpbWFyeWNw
# cy5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AcABvAGwAaQBjAHkA
# XwBzAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAGfyhqWY
# 4FR5Gi7T2HRnIpsLlhHhY5KZQpZ90nkMkMFlXy4sPvjDctFtg/6+P+gKyju/R6mj
# 82nbY78iNaWXXWWEkH2LRlBV2AySfNIaSxzzPEKLUtCw/WvjPgcuKZvmPRul1LUd
# d5Q54ulkyUQ9eHoj8xN9ppB0g430yyYCRirCihC7pKkFDJvtaPpoLpWgKj8qa1hJ
# Yx8JaW5amJbkg/TAj/NGK978O9C9Ne9uJa7lryft0N3zDq+ZKJeYTQ49C/IIidYf
# wzIY4vDFLc5bnrRJOQrGCsLGra7lstnbFYhRRVg4MnEnGn+x9Cf43iw6IGmYslmJ
# aG5vp7d0w0AFBqYBKig+gj8TTWYLwLNN9eGPfxxvFX1Fp3blQCplo8NdUmKGwx1j
# NpeG39rz+PIWoZon4c2ll9DuXWNB41sHnIc+BncG0QaxdR8UvmFhtfDcxhsEvt9B
# xw4o7t5lL+yX9qFcltgA1qFGvVnzl6UJS0gQmYAf0AApxbGbpT9Fdx41xtKiop96
# eiL6SJUfq/tHI4D1nvi/a7dLl+LrdXga7Oo3mXkYS//WsyNodeav+vyL6wuA6mk7
# r/ww7QRMjt/fdW1jkT3RnVZOT7+AVyKheBEyIXrvQQqxP/uozKRdwaGIm1dxVk5I
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIVWzCCFVcCAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAQNeJRyZH6MeuAAAAAABAzAN
# BglghkgBZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQg0FhnFqkU
# jY6OKL2syyGrQrQFNeapNhpCKoJH9IGNyDEwQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQAPZPJXew5SFFMtcudFAOzhHi6YfWb/s5VC2Dm32Q6M
# G9PpaQrmd2N6I7E7642U6H5wFe8DGY/7Ci4MtqzIB9e6RzBeTsvcSuJ3HHDqJK9C
# euxfxbsl2lU2Itu00210UclVSu0vLoRrnvyD8rYjv79RHKXr68elHHuQBomXHAy+
# 62c0WP/a/zean8POTFy7uktTuV1Jyv28u5CalD55m/DvRCa58BSZVb5hlpji1VCk
# HA05ULj6hBd48M8Pp5G01fnZSLHC0e3uviXGmRvKq7pXF8QCC7pKbxXjtt3MePhN
# nch5kFFZ0Ha+yVt88ey5WtHYuS5/oBlxouMmnjSGkJS6oYIS5TCCEuEGCisGAQQB
# gjcDAwExghLRMIISzQYJKoZIhvcNAQcCoIISvjCCEroCAQMxDzANBglghkgBZQME
# AgEFADCCAVEGCyqGSIb3DQEJEAEEoIIBQASCATwwggE4AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIMcloLSJShbs4RuCqDhyOb50UkrtWxz42R5X1lUs
# MiECAgZcdUDNlv0YEzIwMTkwMzE1MDEzNzA2LjEyN1owBIACAfSggdCkgc0wgcox
# CzAJBgNVBAYTAlVTMQswCQYDVQQIEwJXQTEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQg
# SXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJjAkBgNVBAsTHVRoYWxlcyBUU1Mg
# RVNOOjg2REYtNEJCQy05MzM1MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFt
# cCBzZXJ2aWNloIIOPDCCBPEwggPZoAMCAQICEzMAAADeNeu+CVTE7D0AAAAAAN4w
# DQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcN
# MTgwODIzMjAyNzAwWhcNMTkxMTIzMjAyNzAwWjCByjELMAkGA1UEBhMCVVMxCzAJ
# BgNVBAgTAldBMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQg
# Q29ycG9yYXRpb24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlv
# bnMgTGltaXRlZDEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046ODZERi00QkJDLTkz
# MzUxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIHNlcnZpY2UwggEiMA0G
# CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDdeXdpYgiTq7rqbSe4JEj7RofMLbSS
# jXTRN9muBz9kkQARzNS9YwgjSj0IOF65eZ66uhp1mluhXvQVyyL6iSSxDjGXGKDv
# JcZk+vtYkHX98mo4+hVc0tAihddssmhKkjD5S2Du075LhSBlTlz+JGc5rcro3fu8
# tAJmKq7u5w3dCLJ7B8J28n9dnmmF5JNsf7Mn2+k4QQs74KC27XQajfp1SS5baix9
# ZmyE2aMBtiJBdPAJGfCUz9oKcpBcUeE/+HObnSa7tHB4HTrWgXQKtqyV0fAXTq+t
# DmxphDO1DlaL+bqA5QS8c83sRA8i+7tnDRYboHar3uWBY5GPrVfKLV4JAgMBAAGj
# ggEbMIIBFzAdBgNVHQ4EFgQUx0ywgRh/nyIKIB+b89wxMm/t6q4wHwYDVR0jBBgw
# FoAU1WM6XIoxkPNDe3xGG8UzaFqFbVUwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDov
# L2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljVGltU3RhUENB
# XzIwMTAtMDctMDEuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNUaW1TdGFQQ0FfMjAx
# MC0wNy0wMS5jcnQwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcDCDAN
# BgkqhkiG9w0BAQsFAAOCAQEACaDJDoNFPtFuBw68Oy1o6CRBYZjnupZGbUgFl1mP
# pOISAsBuTJRtHKuOS5Z/r1IfhYMipcNllRKPC+VGyGcwDKFhcLfK5x3q1Bh9wCsc
# KjnbwiOWMWsnOe+wqTdQP09921z3/nS0ker7ATQq/vO0+EMJ0kAwgRmsjx6g4tsR
# G/+YKdkBEWW5NjaP7pfWqMFdYgAo5hNVpHv3hcm6BmbGfhW5tVIlow9EXU275bp3
# fihjTXgNHf+VUJ8TnByBWIH9MkyrPAy8tm0dQvJqHm1ba4vKbwTTv4s/8Pvrmu+d
# f/9NLFL4WL2fVEsSObY3AxTvU/3/HYaNozfLjTOHoR8ztzCCBnEwggRZoAMCAQIC
# CmEJgSoAAAAAAAIwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRp
# ZmljYXRlIEF1dGhvcml0eSAyMDEwMB4XDTEwMDcwMTIxMzY1NVoXDTI1MDcwMTIx
# NDY1NVowfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQG
# A1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwggEiMA0GCSqGSIb3
# DQEBAQUAA4IBDwAwggEKAoIBAQCpHQ28dxGKOiDs/BOX9fp/aZRrdFQQ1aUKAIKF
# ++18aEssX8XD5WHCdrc+Zitb8BVTJwQxH0EbGpUdzgkTjnxhMFmxMEQP8WCIhFRD
# DNdNuDgIs0Ldk6zWczBXJoKjRQ3Q6vVHgc2/JGAyWGBG8lhHhjKEHnRhZ5FfgVSx
# z5NMksHEpl3RYRNuKMYa+YaAu99h/EbBJx0kZxJyGiGKr0tkiVBisV39dx898Fd1
# rL2KQk1AUdEPnAY+Z3/1ZsADlkR+79BL/W7lmsqxqPJ6Kgox8NpOBpG2iAg16Hgc
# sOmZzTznL0S6p/TcZL2kAcEgCZN4zfy8wMlEXV4WnAEFTyJNAgMBAAGjggHmMIIB
# 4jAQBgkrBgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQU1WM6XIoxkPNDe3xGG8UzaFqF
# bVUwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1Ud
# EwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU1fZWy4/oolxiaNE9lJBb186aGMQwVgYD
# VR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwv
# cHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsGAQUFBwEB
# BE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9j
# ZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcnQwgaAGA1UdIAEB/wSBlTCB
# kjCBjwYJKwYBBAGCNy4DMIGBMD0GCCsGAQUFBwIBFjFodHRwOi8vd3d3Lm1pY3Jv
# c29mdC5jb20vUEtJL2RvY3MvQ1BTL2RlZmF1bHQuaHRtMEAGCCsGAQUFBwICMDQe
# MiAdAEwAZQBnAGEAbABfAFAAbwBsAGkAYwB5AF8AUwB0AGEAdABlAG0AZQBuAHQA
# LiAdMA0GCSqGSIb3DQEBCwUAA4ICAQAH5ohRDeLG4Jg/gXEDPZ2joSFvs+umzPUx
# vs8F4qn++ldtGTCzwsVmyWrf9efweL3HqJ4l4/m87WtUVwgrUYJEEvu5U4zM9GAS
# inbMQEBBm9xcF/9c+V4XNZgkVkt070IQyK+/f8Z/8jd9Wj8c8pl5SpFSAK84Dxf1
# L3mBZdmptWvkx872ynoAb0swRCQiPM/tA6WWj1kpvLb9BOFwnzJKJ/1Vry/+tuWO
# M7tiX5rbV0Dp8c6ZZpCM/2pif93FSguRJuI57BlKcWOdeyFtw5yjojz6f32WapB4
# pm3S4Zz5Hfw42JT0xqUKloakvZ4argRCg7i1gJsiOCC1JeVk7Pf0v35jWSUPei45
# V3aicaoGig+JFrphpxHLmtgOR5qAxdDNp9DvfYPw4TtxCd9ddJgiCGHasFAeb73x
# 4QDf5zEHpJM692VHeOj4qEir995yfmFrb3epgcunCaw5u+zGy9iCtHLNHfS4hQEe
# gPsbiSpUObJb2sgNVZl6h3M7COaYLeqN4DMuEin1wC9UJyH3yKxO2ii4sanblrKn
# QqLJzxlBTeCG+SqaoxFmMNO7dDJL32N79ZmKLxvHIa9Zta7cRDyXUHHXodLFVeNp
# 3lfB0d4wwP3M5k37Db9dT+mdHhk4L7zPWAUu7w2gUDXa7wknHNWzfjUeCLraNtvT
# X4/edIhJEqGCAs4wggI3AgEBMIH4oYHQpIHNMIHKMQswCQYDVQQGEwJVUzELMAkG
# A1UECBMCV0ExEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0IElyZWxhbmQgT3BlcmF0aW9u
# cyBMaW1pdGVkMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjo4NkRGLTRCQkMtOTMz
# NTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgc2VydmljZaIjCgEBMAcG
# BSsOAwIaAxUAW/eWCXH2dNIMG8hPQuIzTxUfvsyggYMwgYCkfjB8MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQg
# VGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQUFAAIFAOA1f7QwIhgPMjAx
# OTAzMTUwOTM0NDRaGA8yMDE5MDMxNjA5MzQ0NFowdzA9BgorBgEEAYRZCgQBMS8w
# LTAKAgUA4DV/tAIBADAKAgEAAgIeMgIB/zAHAgEAAgIRfTAKAgUA4DbRNAIBADA2
# BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIB
# AAIDAYagMA0GCSqGSIb3DQEBBQUAA4GBACxyczAPRLc4DJCfsPTarYPJS/avNvPp
# rMTS38qGCL1OcwU+X42gAV1451Mf5Y45OyVNZIXeLp5PazpQXUIm9Shwi9XE8zYh
# eKgPZIc06RtnlXF1Td3almoloORYKYFw1+JdoKL9EyTJo31rFhxM3gXZVTZvau6a
# aqoBpw2GLQyaMYIDDTCCAwkCAQEwgZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENB
# IDIwMTACEzMAAADeNeu+CVTE7D0AAAAAAN4wDQYJYIZIAWUDBAIBBQCgggFKMBoG
# CSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0BCQQxIgQgWHfiWYTf
# RkArKAarHj4S33BTKInHed8iwBNS93xRm9UwgfoGCyqGSIb3DQEJEAIvMYHqMIHn
# MIHkMIG9BCDC4QJOqyVsHI8VLxVAg7jL6vNR2772PHfxlRPwjFRVSTCBmDCBgKR+
# MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMT
# HU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAA3jXrvglUxOw9AAAA
# AADeMCIEIEZvTgqzBKdrtHRQwxU+Y4kPkSo++aGfptM6V4CFln8EMA0GCSqGSIb3
# DQEBCwUABIIBABtcpC2nVWqVbM0BIkJVwdQWDKKb8cJWZcM+P4SJWYOgY/lGI7Kd
# Hrz9Kty5yc5XbqFF2EZY8qWiAnYeqfHzAzPuMVzM8TKwtSz+GM4A3Nf+bpeD28A8
# NizriMUAguLh8AJxANVL8MbN7a5gQGV+oYlngSkJPNEB3RNavDDbnVn19j98tZR8
# 9FKG0RtQCOkA9LGaeNhamo69sF2OTS0NYfSnow9cXmjFrZOY3a8W99+ureQXQGQz
# LyOUwYnnYroHhN9xw+qSa9jhamq0KI+mqGH2dYiam1sYXE9ZPJ2BgNWsrs5zAhT+
# 36gPJK8Rn9f1aZCsSDpbQZWhpoFcDplhabY=
# SIG # End signature block
