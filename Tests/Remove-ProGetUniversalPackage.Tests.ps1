
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

BeforeAll {
    Set-StrictMode -Version 'Latest'

    & (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

    $script:testNum = 0
    $script:testDir = $null
    $script:feedName = $PSCommandPath | Split-Path -Leaf
    $script:session = New-ProGetTestSession

    function GivenPackage
    {
        param(
            $Name,
            $Version,
            $InGroup
        )

        $packagePath = Join-Path -Path $script:testDir -ChildPath ('package.{0}.upack' -f [IO.Path]::GetRandomFileName())
        New-ProGetUniversalPackage -OutFile $packagePath -Version $Version -Name $Name -GroupName $InGroup
        Publish-ProGetUniversalPackage -Session $script:session -FeedName $script:feedName -PackagePath $packagePath
    }

    function ThenError
    {
        [Diagnostics.CodeAnalysis.SuppressMessage('PSAvoidAssignmentToAutomaticVariable', '')]
        param(
            [String] $Matches
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

        $package = Get-ProGetUniversalPackage -Session $script:session `
                                              -FeedName $script:feedName `
                                              -Name $Named `
                                              -GroupName $InGroup `
                                              -ErrorAction Ignore

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

        $package = Get-ProGetUniversalPackage -Session $script:session -FeedName $script:feedName -Name $Named -GroupName $InGroup
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
        Remove-ProGetUniversalPackage -Session $script:session -FeedName $script:feedName -Name $Named -Version $AtVersion -GroupName $InGroup -WhatIf:$WhatIf
    }
}

Describe 'Remove-ProGetUniversalPackage' {
    BeforeEach {
        $script:testDir = Join-Path -Path $TestDrive -ChildPath $script:testNum
        New-Item -Path $script:testDir -ItemType 'Directory'
        Get-ProGetFeed -Session $script:session -Name $script:feedName -ErrorAction Ignore |
            Remove-ProGetFeed -Session $script:session -Force
        New-ProGetFeed -Session $script:session -Name $script:feedName -Type 'Universal'
    }

    AfterEach {
        $script:testNum += 1
    }

    It 'deletes package' {
        GivenPackage 'Fubar' '0.0.0'
        WhenDeletingPackage -Named 'Fubar' -AtVersion '0.0.0'
        ThenPackageDeleted 'Fubar'
    }

    It 'when package with the same name in a group' {
        GivenPackage 'Fubar' '0.0.0'
        GivenPackage 'Fubar' '0.0.0' -InGroup 'group'
        WhenDeletingPackage -Named 'Fubar' -AtVersion '0.0.0'
        ThenPackageDeleted 'Fubar'
        ThenPackageNotDeleted 'Fubar' -InGroup 'group'
    }

    It 'when package is in a group and package with the same name not in a group' {
        GivenPackage 'Fubar' '0.0.0'
        GivenPackage 'Fubar' '0.0.0' -InGroup 'group'
        WhenDeletingPackage -Named 'Fubar' -AtVersion '0.0.0' -InGroup 'group'
        ThenPackageDeleted 'Fubar' -InGroup 'group'
        ThenPackageNotDeleted 'Fubar'
    }

    It 'when package doesn''t exist' {
        WhenDeletingPackage -Named 'Fubar' -AtVersion '0.0.0' -ErrorAction SilentlyContinue
        ThenError -Matches 'package\ not\ found'
    }

    It 'when using WhatIf' {
        GivenPackage 'Fubar' '0.0.0'
        WhenDeletingPackage -Named 'Fubar' -AtVersion '0.0.0' -WhatIf
        ThenPackageNotDeleted 'Fubar'
    }

    It 'when there are multiple versions' {
        GivenPackage 'Fubar' '0.0.0'
        GivenPackage 'Fubar' '0.0.1'
        GivenPackage 'Fubar' '0.0.2'
        WhenDeletingPackage -Named 'Fubar' -AtVersion '0.0.1'
        ThenPackageDeleted 'Fubar' -AtVersion '0.0.1'
        ThenPackageNotDeleted 'Fubar' -AtVersion '0.0.0'
        ThenPackageNotDeleted 'Fubar' -AtVersion '0.0.2'
    }

    It 'when package doesn''t exist' {
        WhenDeletingPackage -Named 'Fubar' -AtVersion '0.0.0' -ErrorAction SilentlyContinue
        ThenError -Matches 'package\ not\ found'
    }

    It 'when package doesn''t exist and ignoring errors' {
        WhenDeletingPackage -Named 'Fubar' -AtVersion '0.0.0' -ErrorAction Ignore
        ThenNoError
    }
}
