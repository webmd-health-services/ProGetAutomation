
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

BeforeAll {
    Set-StrictMode -Version 'Latest'

    & (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

    $script:session = New-ProGetTestSession
    $script:result = $null

    function GivenFeed
    {
        param(
            $Name,
            $OfType
        )

        New-ProGetFeed -Session $script:session -Name $Name -Type $OfType
    }

    function ThenFeedExists
    {
        $script:result | Should -BeTrue
    }

    function ThenFeedDoesNotExist
    {
        $script:result | Should -BeFalse
    }

    function WhenTesting
    {
        param(
            $Name,
            $OfType
        )

        $script:result = Test-ProGetFeed -Session $script:session -Name $Name -Type $OfType
    }
}

Describe 'Test-ProGetFeed' {
    BeforeEach {
        $script:result = $null

        Get-ProGetFeed -Session $script:session | Remove-ProGetFeed -Session $script:session -Force
    }

    It 'detects existing feed' {
        GivenFeed 'Fubar' -OfType 'Universal'
        WhenTesting 'Fubar' -OfType 'Universal'
        ThenFeedExists
    }

    It 'detects non-existent feed' {
        WhenTesting 'Fubar' -OfType 'Universal'
        ThenFeedDoesNotExist
    }

    It 'uses feed type to determine existence' {
        GivenFeed 'Fubar' -OfType 'Universal'
        WhenTesting 'Fubar' -OfType 'NuGet'
        ThenFeedDoesNotExist
    }
}