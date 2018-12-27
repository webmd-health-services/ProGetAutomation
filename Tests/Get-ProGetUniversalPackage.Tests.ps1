
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

$session = New-ProGetTestSession
$result = $null
$upackFile = $null
$feedName = 'Get-ProGetUniversalPackage.Tests.ps1'

function GivenFeed
{
    param(
        $Name
    )

    Get-ProGetFeed -Session $Session -Name $Name | Remove-ProGetFeed -Session $Session -Force
    New-ProGetFeed -Session $session -Name $Name -Type 'ProGet'
}

function GivenPackage
{
    param(
        [Parameter(Mandatory,Position=0)]
        [string]
        $Named,

        [string]
        $InGroup
    )

    $params = @{ }
    if( $InGroup )
    {
        $params['GroupName'] = $InGroup
    }

    $script:upackFile = New-ProGetUniversalPackage -OutFile (Join-Path -Path $TestDrive.FullName -ChildPath ('{0}{1}.zip' -f $InGroup,$Named)) -Version '0.0.0' -Name $Named @params
    Publish-ProGetUniversalPackage -Session $session -FeedName $feedName -PackagePath $upackFile 
}

function Init
{
    $script:result = $null
    $script:upackFile = $null
    GivenFeed $feedName
}

function ThenError
{
    param(
        $Matches
    )

    It ('should write error') {
        $Global:Error | Should -Match $Matches
    }
}

function ThenNoErrors
{
    param(
    )

    It ('should write no errors') {
        $Global:Error | Should -BeNullOrEmpty
    }
}

function ThenNothingReturned
{
    It ('should return nothing') {
        $result | Should -BeNullOrEmpty
    }
}

function ThenPackageReturned
{
    param(
        [string[]]
        $Named,

        $InGroup = ''
    )

    It ('should return package') {
        $result | Should -HaveCount $Named.Count
        foreach( $name in $Named )
        {
            $result | Where-Object { $_.name -eq $name } | Should -not -BeNullOrEmpty
            $result | Where-Object { $_.group -eq $InGroup } | Should -HaveCount $Named.Count
        }
    }
}

function WhenGettingPackage
{
    [CmdletBinding()]
    param(
        $Named,
        $InGroup
    )

    $params = @{ }
    if( $PSBoundParameters.ContainsKey('Named') )
    {
        $params['Name'] = $Named
    }
    if( $PSBoundParameters.ContainsKey('InGroup') )
    {
        $params['GroupName'] = $InGroup
    }
    $Global:Error.Clear()
    $script:result = Get-ProGetUniversalPackage -Session $session -FeedName $feedName @params
}

Describe 'Get-ProGetUniversalPackage.when package doesn''t exist' {
    Init
    WhenGettingPackage 'Fubar' -ErrorAction SilentlyContinue
    ThenNothingReturned
    ThenError -Matches 'package\ was\ not\ found'
}

Describe 'Get-ProGetUniversalPackage.when package doesn''t exist and ignoring any errors' {
    Init
    WhenGettingPackage 'Fubar' -ErrorAction Ignore
    ThenNothingReturned
    ThenNoErrors
}

Describe 'Get-ProGetUniversalPackage.when getting a package' {
    Init
    GivenPackage 'Snafu'
    WhenGettingPackage 'Snafu'
    ThenPackageReturned 'Snafu'
    ThenNoErrors
}

Describe 'Get-ProGetUniversalPackage.when getting all packages' {
    Init
    GivenPackage 'Snafu'
    GivenPackage 'Fizz'
    GivenPackage 'Buzz'
    WhenGettingPackage
    ThenPackageReturned 'Snafu','Fizz','Buzz'
    ThenNoErrors
}

Describe 'Get-ProGetUniversalPackage.when getting with wildcard' {
    Init
    GivenPackage 'Snafu'
    GivenPackage 'Fizz'
    GivenPackage 'Buzz'
    WhenGettingPackage '*zz'
    ThenPackageReturned 'Fizz','Buzz'
    ThenNoErrors
}

if( $false )
{
    # There's currently a bug in ProGet that doesn't allow this.
    Describe 'Get-ProGetUniversalPackage.when getting all packages in a group' {
        Init
        GivenPackage 'Snafu0'
        GivenPackage 'Snafu1' -InGroup 'One'
        GivenPackage 'Snafu21' -InGroup 'Two'
        GivenPackage 'Snafu22' -InGroup 'Two'
        GivenPackage 'Snafu23' -InGroup 'Two'
        GivenPackage 'Snafu3' -InGroup 'Three'
        WhenGettingPackage -InGroup 'Two'
        ThenPackageReturned 'Snafu21','Snafu22','Snafu23' -InGroup 'Two'
        ThenNoErrors
    }
}

Describe 'Get-ProGetUniversalPackage.when getting package in a group and there are duplicate packages in other groups' {
    Init
    GivenPackage 'Snafu'
    GivenPackage 'Snafu' -InGroup 'One'
    GivenPackage 'Snafu' -InGroup 'Two'
    GivenPackage 'Snafu' -InGroup 'Three'
    WhenGettingPackage 'Snafu' -InGroup 'Three'
    ThenPackageReturned 'Snafu' -InGroup 'Three'
    ThenNoErrors
}

Describe 'Get-ProGetUniversalPackage.when getting getting packages by group using wildcards' {
    Init
    GivenPackage 'Snafu0'
    GivenPackage 'Snafu1' -InGroup 'One'
    GivenPackage 'Snafu2' -InGroup 'Two'
    GivenPackage 'Snafu3' -InGroup 'Three'
    WhenGettingPackage -InGroup 'O*'
    ThenPackageReturned 'Snafu1' -InGroup 'One'
    ThenNoErrors
}

Describe 'Get-ProGetUniversalPackage.when passing empty string to group' {
    Init
    GivenPackage 'Snafu'
    GivenPackage 'Snafu' -InGroup 'One'
    GivenPackage 'Snafu' -InGroup 'Two'
    GivenPackage 'Snafu' -InGroup 'Three'
    WhenGettingPackage 'Snafu' -InGroup ''
    ThenPackageReturned 'Snafu'
    ThenNoErrors
}

Describe 'Get-ProGetUniversalPackage.when passing empty string to name' {
    Init
    GivenPackage 'Snafu1'
    GivenPackage 'Snafu2'
    WhenGettingPackage ''
    ThenPackageReturned 'Snafu1','Snafu2'
    ThenNoErrors
}

Describe 'Get-ProGetUniversalPackage.when searching for packages with the same name across groups with group wildcard' {
    Init
    GivenPackage 'Snafu'
    GivenPackage 'Snafu' -InGroup 'One'
    GivenPackage 'Snafu' -InGroup 'Two'
    GivenPackage 'Snafu' -InGroup 'Three'
    WhenGettingPackage 'Snafu' -InGroup 'O*'
    ThenPackageReturned 'Snafu' -InGroup 'One'
    ThenNoErrors
}
