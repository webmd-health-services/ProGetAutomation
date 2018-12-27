
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

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

    $packagePath = Join-Path -Path $TestDrive.FullName -ChildPath ('package.{0}.upack' -f [IO.Path]::GetRandomFileName())
    New-ProGetUniversalPackage -OutFile $packagePath -Version $Version -Name $Name -GroupName $InGroup
    Publish-ProGetUniversalPackage -Session $session -FeedName $feedName -PackagePath $packagePath
}

function Init
{
    Get-ProGetFeed -Session $session -Name $feedName | Remove-ProGetFeed -Session $session -Force
    New-ProGetFeed -Session $session -Name $feedName -Type 'ProGet'
}

function ThenError
{
    param(
        $Matches
    )

    It ('should write an error') {
        $Global:Error | Should -Match $Matches

    }
}

function ThenNoError
{
    It ('should not write any errors') {
        $Global:Error | Should -BeNullOrEmpty
    }
}

function ThenPackageDeleted
{
    param(
        $Named,
        $InGroup,
        $AtVersion
    )

    It ('should delete the package') {
        $package = Get-ProGetUniversalPackage -Session $session -FeedName $feedName -Name $Named -GroupName $InGroup -ErrorAction Ignore 
        if( $AtVersion )
        {
            $package = $package.versions | Where-Object { $_ -eq $AtVersion }
        }
        $package | Should -BeNullOrEmpty
    }
}

function ThenPackageNotDeleted
{
    param(
        $Named,

        $InGroup,

        $AtVersion
    )

    It ('should not delete the package') {
        $package = Get-ProGetUniversalPackage -Session $session -FeedName $feedName -Name $Named -GroupName $InGroup 
        if( $AtVersion )
        {
            $package = $package.versions | Where-Object { $_ -eq $AtVersion }
        }
        $package | Should -Not -BeNullOrEmpty
    }
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

Describe 'Remove-ProGetUniversalPackage' {
    Init
    GivenPackage 'Fubar' '0.0.0'
    WhenDeletingPackage -Named 'Fubar' -AtVersion '0.0.0'
    ThenPackageDeleted 'Fubar'
}

Describe 'Remove-ProGetUniversalPackage.when package with the same name in a group' {
    Init
    GivenPackage 'Fubar' '0.0.0'
    GivenPackage 'Fubar' '0.0.0' -InGroup 'group'
    WhenDeletingPackage -Named 'Fubar' -AtVersion '0.0.0'
    ThenPackageDeleted 'Fubar'
    ThenPackageNotDeleted 'Fubar' -InGroup 'group'
}

Describe 'Remove-ProGetUniversalPackage.when package is in a group and package with the same name not in a group' {
    Init
    GivenPackage 'Fubar' '0.0.0'
    GivenPackage 'Fubar' '0.0.0' -InGroup 'group'
    WhenDeletingPackage -Named 'Fubar' -AtVersion '0.0.0' -InGroup 'group'
    ThenPackageDeleted 'Fubar' -InGroup 'group'
    ThenPackageNotDeleted 'Fubar' 
}

Describe 'Remove-ProGetUniversalPackage.when package doesn''t exist' {
    Init
    WhenDeletingPackage -Named 'Fubar' -AtVersion '0.0.0' -ErrorAction SilentlyContinue
    ThenError -Matches 'package\ not\ found'
}

Describe 'Remove-ProGetUniversalPackage.when using WhatIf' {
    Init
    GivenPackage 'Fubar' '0.0.0'
    WhenDeletingPackage -Named 'Fubar' -AtVersion '0.0.0' -WhatIf
    ThenPackageNotDeleted 'Fubar'
}

Describe 'Remove-ProGetUniversalPackage.when there are multiple versions' {
    Init
    GivenPackage 'Fubar' '0.0.0'
    GivenPackage 'Fubar' '0.0.1'
    GivenPackage 'Fubar' '0.0.2'
    WhenDeletingPackage -Named 'Fubar' -AtVersion '0.0.1'
    ThenPackageDeleted 'Fubar' -AtVersion '0.0.1'
    ThenPackageNotDeleted 'Fubar' -AtVersion '0.0.0'
    ThenPackageNotDeleted 'Fubar' -AtVersion '0.0.2'
}

Describe 'Remove-ProGetUniversalPackage.when package doesn''t exist' {
    Init
    WhenDeletingPackage -Named 'Fubar' -AtVersion '0.0.0' -ErrorAction SilentlyContinue
    ThenError -Matches 'package\ not\ found'
}

Describe 'Remove-ProGetUniversalPackage.when package doesn''t exist and ignoring errors' {
    Init
    WhenDeletingPackage -Named 'Fubar' -AtVersion '0.0.0' -ErrorAction Ignore
    ThenNoError
}

