
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
        Get-ProGetFeed -Session $script:session -Force | Remove-ProGetFeed -Session $script:session -Force
        $Global:Error.Clear()
    }

    It 'creates universal feeds' {
        New-ProGetFeed -Session $script:session -Type 'Universal' -Name 'FeedTest'
        $feedExists = Test-ProGetFeed -Session $script:session -Type 'Universal' -Name 'FeedTest'
        $Global:Error | Should -BeNullOrEmpty
        $feedExists | Should -BeTrue
    }

    It 'does not create duplicate feeds' {
        New-ProGetFeed -Session $script:session -Type 'Universal' -Name 'FeedTest'
        New-ProGetFeed -Session $script:session -Type 'Universal' -Name 'FeedTest' -ErrorAction SilentlyContinue
        $Global:Error | Should -Match 'A feed with that name and type already exists'
    }

    It 'can ignore errors' {
        New-ProGetFeed -Session $script:session -Type 'Universal' -Name 'FeedTest'
        New-ProGetFeed -Session $script:session -Type 'Universal' -Name 'FeedTest' -ErrorAction Ignore
        $Global:Error | Should -BeNullOrEmpty
    }

    It 'rejects requests with an invalid API key' {
        $script:session.ApiKey = '==InvalidAPIKey=='
        New-ProGetFeed -Session $script:session -Type 'Universal' -Name 'FeedTest' -ErrorAction SilentlyContinue
    }

    It 'validates session has an API key' {
        $script:session.ApiKey = $null
        New-ProGetFeed -Session $script:session -Type 'Universal' -Name 'FeedTest' -ErrorAction SilentlyContinue
        $Global:Error | Should -Match 'This function uses ProGet''s Native API, which requires an API key.'
    }

    It 'validates feed type' {
        New-ProGetFeed -Session $script:session -Type 'InvalidFeedType' -Name 'FeedTest' -ErrorAction SilentlyContinue
        $Global:Error |
            Should -Match 'The INSERT statement conflicted with the CHECK constraint "CK__Feeds__FeedType_Name"'
    }
}