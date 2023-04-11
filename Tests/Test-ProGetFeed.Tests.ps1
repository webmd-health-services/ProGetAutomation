
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

        New-ProGetFeed -Session $script:session -Name $Name -Type 'universal'
    }

    function ThenFeedExists
    {
        $script:result | Should -BeTrue
    }

    function ThenFeedDoesNotExist
    {
        $script:result | Should -BeFalse
        $null | Should -BeFalse
    }

    function WhenTesting
    {
        param(
            $Name
        )

        $script:result = Test-ProGetFeed -Session $script:session -Name $Name
        $Global:Error | Should -BeNullOrEmpty
    }
}

Describe 'Test-ProGetFeed' {
    BeforeEach {
        $Global:Error.Clear()
        $script:result = $null
        Get-ProGetFeed -Session $script:session | Remove-ProGetFeed -Session $script:session -Force
    }

    It 'detects existing feed' {
        GivenFeed 'Test-ProGetFeed1'
        WhenTesting 'Test-ProGetFeed1'
        ThenFeedExists
    }

    It 'detects non-existent feed' {
        WhenTesting 'Test-ProGetFeed2'
        ThenFeedDoesNotExist
    }
}