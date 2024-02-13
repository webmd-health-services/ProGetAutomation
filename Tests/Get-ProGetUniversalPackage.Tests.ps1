
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

BeforeAll {
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

        Get-ProGetFeed -Session $Session -Name $Name -ErrorAction Ignore | Remove-ProGetFeed -Session $Session -Force
        New-ProGetFeed -Session $session -Name $Name -Type 'Universal'
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

        $filepath = Join-Path -Path $TestDrive -ChildPath ('package.{0}.upack' -f [IO.Path]::GetRandomFileName())
        $upackFile = New-ProGetUniversalPackage -OutFile $filepath -Version '0.0.0' -Name $Named @params
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

        $Global:Error | Should -Match $Matches
    }

    function ThenNoErrors
    {
        param(
        )

        $Global:Error | Should -BeNullOrEmpty
    }

    function ThenNothingReturned
    {
        $result | Should -BeNullOrEmpty
    }

    function ThenPackageReturned
    {
        param(
            [string[]]
            $Named,

            $InGroup = ''
        )
        $result = $script:result
        $result | Should -HaveCount $Named.Count
        foreach( $name in $Named )
        {
            $result | Where-Object { $_.name -eq $name } | Should -not -BeNullOrEmpty
            $result | Where-Object { $_.group -eq $InGroup } | Should -HaveCount $Named.Count
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
}

Describe 'Get-ProGetUniversalPackage when package doesn''t exist' {
    BeforeEach {
        Init
    }

    It 'should return nothing and provide an error' {
        WhenGettingPackage 'Fubar' -ErrorAction SilentlyContinue
        ThenNothingReturned
        ThenError -Matches 'package\ was\ not\ found'
    }

    It 'should return nothing and provide no error' {
        WhenGettingPackage 'Fubar' -ErrorAction Ignore
        ThenNothingReturned
        ThenNoErrors
    }
}

Describe 'Get-ProGetUniversalPackage' {
    BeforeEach {
        Init
    }

    It 'should return package' {
        GivenPackage 'Snafu'
        WhenGettingPackage 'Snafu'
        ThenPackageReturned 'Snafu'
        ThenNoErrors
    }

    It 'should return all packages when name passed is empty string' {
        GivenPackage 'Snafu1'
        GivenPackage 'Snafu2'
        WhenGettingPackage ''
        ThenPackageReturned 'Snafu1','Snafu2'
        ThenNoErrors
    }

    It 'should return all packages when no group or name provided' {
        GivenPackage 'Snap'
        GivenPackage 'Fizz'
        GivenPackage 'Buzz'
        WhenGettingPackage
        ThenPackageReturned 'Snap','Fizz','Buzz'
        ThenNoErrors
    }

    It 'should return packages using wildcard on passed name' {
        GivenPackage 'Fizz'
        GivenPackage 'Buzz'
        GivenPackage 'Bizzes'
        WhenGettingPackage '*zz'
        ThenPackageReturned 'Fizz','Buzz'
        ThenNoErrors
    }
}

Describe 'Get-ProGetUniversalPackage grab packages by group' {
    BeforeEach {
        Init
    }

    It 'should only return package within provided group when duplicate named packages are in other groups' {
        GivenPackage 'Snafu'
        GivenPackage 'Snafu' -InGroup 'One'
        GivenPackage 'Snafu' -InGroup 'Two'
        GivenPackage 'Snafu' -InGroup 'Three'
        WhenGettingPackage 'Snafu' -InGroup 'Three'
        ThenPackageReturned 'Snafu' -InGroup 'Three'
        ThenNoErrors
    }

    It 'should return all packages within a group' {
        GivenPackage 'Snafu'
        GivenPackage 'Snafu' -InGroup 'One'
        GivenPackage 'Snafu' -InGroup 'Two'
        GivenPackage 'Snafu22' -InGroup 'Two'
        GivenPackage 'Snafu23' -InGroup 'Two'
        GivenPackage 'Snafu' -InGroup 'Three'
        WhenGettingPackage -InGroup 'Two'
        ThenPackageReturned 'Snafu','Snafu22','Snafu23' -InGroup 'Two'
        ThenNoErrors
    }

    It 'should return all packages within a group using a wildcard on the group name' {
        GivenPackage 'Snafu'
        GivenPackage 'Snafu' -InGroup 'One'
        GivenPackage 'Snafu' -InGroup 'Two'
        GivenPackage 'Snafu' -InGroup 'Three'
        WhenGettingPackage -InGroup 'O*'
        ThenPackageReturned 'Snafu' -InGroup 'One'
        ThenNoErrors
    }

    # Test is failing in Proget v2023. Not fixed in 2023.28 still.
    # When group is not passed in query string it grabs the first package with a matching name, no matter what group it is.
    # Should only grab the package with the name that is not in a group.
    # This is also failing a test in Remove-ProGetUniversalPackage.Tests ("should delete the package with no group").
    It 'should return same named package that is not in group when group passed is an empty string' {
        GivenPackage 'Snafu'
        GivenPackage 'Snafu' -InGroup 'One'
        GivenPackage 'Snafu' -InGroup 'Two'
        GivenPackage 'Snafu' -InGroup 'Three'
        WhenGettingPackage 'Snafu' -InGroup ''
        ThenPackageReturned 'Snafu'
        ThenNoErrors
    }
}