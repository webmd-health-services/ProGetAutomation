
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

BeforeAll {
    & (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)
    
    $feedName = $PSCommandPath | Split-Path -Leaf
    $session = New-ProGetTestSession

    function GivenPackage
    {
        param(
            $Name,
            $Version,
            $InGroup
        )

        $packagePath = Join-Path -Path $TestDrive -ChildPath ('package.{0}.upack' -f [IO.Path]::GetRandomFileName())
        New-ProGetUniversalPackage -OutFile $packagePath -Version $Version -Name $Name -GroupName $InGroup
        Publish-ProGetUniversalPackage -Session $session -FeedName $feedName -PackagePath $packagePath
    }

    function ThenError
    {
        param(
            $Matches
        )

        $Global:Error | Should -Match $Matches
    }

    function ThenNoError
    {
        $Global:Error | Should -BeNullOrEmpty
    }

    function ThenPackageDeleted
    {
        param(
            $Named,
            $InGroup,
            $AtVersion
        )

        $package = Get-ProGetUniversalPackage -Session $session -FeedName $feedName -Name $Named -GroupName $InGroup -ErrorAction Ignore
        if( $AtVersion )
        {
            $package = $package.versions | Where-Object { $_ -eq $AtVersion }
        }
        $package | Should -BeNullOrEmpty
    }

    function ThenPackageNotDeleted
    {
        param(
            $Named,

            $InGroup,

            $AtVersion
        )

        $package = Get-ProGetUniversalPackage -Session $session -FeedName $feedName -Name $Named -GroupName $InGroup
        if( $AtVersion )
        {
            $package = $package.versions | Where-Object { $_ -eq $AtVersion }
        }
        $package | Should -Not -BeNullOrEmpty
    }

    function WhenDeletingPackage
    {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory,ParameterSetName='ByNameAndVersion')]
            [string]
            $Named,

            [Parameter(Mandatory,ParameterSetName='ByNameAndVersion')]
            [string]
            $AtVersion,

            [string]
            $InGroup,

            [Switch]
            $WhatIf
        )

        $Global:Error.Clear()
        Remove-ProGetUniversalPackage -Session $session -FeedName $feedName -Name $Named -Version $AtVersion -GroupName $InGroup -WhatIf:$WhatIf
    }
}

Describe 'Remove-ProGetUniversalPackage' {
    BeforeEach {
        Get-ProGetFeed -Session $session -Name $feedName -ErrorAction Ignore | Remove-ProGetFeed -Session $session -Force
        New-ProGetFeed -Session $session -Name $feedName -Type 'Universal'
    }

    It 'should delete the package' {
        GivenPackage 'Fubar' '0.0.0'
        WhenDeletingPackage -Named 'Fubar' -AtVersion '0.0.0'
        ThenPackageDeleted 'Fubar'
    }

    It 'should only delete provided version when package has multiple versions' {
        GivenPackage 'Fubar' '0.0.0'
        GivenPackage 'Fubar' '0.0.1'
        GivenPackage 'Fubar' '0.0.2'
        WhenDeletingPackage -Named 'Fubar' -AtVersion '0.0.1'
        ThenPackageDeleted 'Fubar' -AtVersion '0.0.1'
        ThenPackageNotDeleted 'Fubar' -AtVersion '0.0.0'
        ThenPackageNotDeleted 'Fubar' -AtVersion '0.0.2'
    }

    It 'should write an error when package doesn''t exist' {
        WhenDeletingPackage -Named 'Fubar' -AtVersion '0.0.0' -ErrorAction SilentlyContinue
        ThenError -Matches 'package\ not\ found'
    }

    It 'should not write an error when package doesn''t exist and ignoring errors' {
        WhenDeletingPackage -Named 'Fubar' -AtVersion '0.0.0' -ErrorAction Ignore
        ThenNoError
    }

    It 'should not delete package when using -WhatIf' {
        GivenPackage 'Fubar' '0.0.0'
        WhenDeletingPackage -Named 'Fubar' -AtVersion '0.0.0' -WhatIf
        ThenPackageNotDeleted 'Fubar'
    }

    # Test is failing in Proget v2023.
    # See Get-ProGetUniversalPackage.Tests for details on Proget issue.
    It 'should delete the same named package that is not in a group'{
        GivenPackage 'Fubar' '0.0.0'
        GivenPackage 'Fubar' '0.0.0' -InGroup 'group'
        WhenDeletingPackage -Named 'Fubar' -AtVersion '0.0.0'
        ThenPackageDeleted 'Fubar'
    }

    It 'should not delete the same named package that is in a group'{
        GivenPackage 'Fubar' '0.0.0'
        GivenPackage 'Fubar' '0.0.0' -InGroup 'group'
        WhenDeletingPackage -Named 'Fubar' -AtVersion '0.0.0'
        ThenPackageNotDeleted 'Fubar' -InGroup 'group'
    }
}