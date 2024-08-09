
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

BeforeAll {
    Set-StrictMode -Version 'Latest'

    & (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

    $script:session = $null
}

Describe 'New-ProGetFeed.create a new Universal package feed' {
    BeforeEach {
        $script:session = New-ProGetTestSession
        Get-ProGetFeed -Session $script:session | Remove-ProGetFeed -Session $script:session -Force
        $Global:Error.Clear()
    }

    It 'creates universal feeds' {
        New-ProGetFeed -Session $script:session -Type 'Universal' -Name 'New-ProGetFeedTest1'
        $feedExists = Test-ProGetFeed -Session $script:session -Name 'New-ProGetFeedTest1'
        $Global:Error | Should -BeNullOrEmpty
        $feedExists | Should -BeTrue
    }

    It 'does not create duplicate feeds' {
        New-ProGetFeed -Session $script:session -Type 'Universal' -Name 'New-ProGetFeedTest2'
        New-ProGetFeed -Session $script:session `
                       -Type 'Universal' `
                       -Name 'New-ProGetFeedTest2' `
                       -ErrorAction SilentlyContinue
        $Global:Error | Should -Match 'A feed with that name already exists'
    }

    It 'can ignore errors' {
        New-ProGetFeed -Session $script:session -Type 'Universal' -Name 'New-ProGetFeedTest3'
        New-ProGetFeed -Session $script:session -Type 'Universal' -Name 'New-ProGetFeedTest3' -ErrorAction Ignore
        $Global:Error | Should -BeNullOrEmpty
    }

    It 'rejects requests with an invalid API key' {
        $script:session.ApiKey = '==InvalidAPIKey=='
        New-ProGetFeed -Session $script:session `
                       -Type 'Universal' `
                       -Name 'New-ProGetFeedTest3' `
                       -ErrorAction SilentlyContinue
    }

    It 'validates feed type' {
        New-ProGetFeed -Session $script:session `
                       -Type 'InvalidFeedType' `
                       -Name 'New-ProGetFeedTest1' `
                       -ErrorAction SilentlyContinue
        $Global:Error | Should -Match 'a valid feed type is required'
    }
}
