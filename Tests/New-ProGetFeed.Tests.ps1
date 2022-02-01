
& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

function Initialize-ProGetFeedTests
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]
        $ProGetSession
    )
    
    $Global:Error.Clear()
    
    # Remove all feeds from target ProGet instance
    Get-ProGetFeed -Session $ProGetSession -Force | Remove-ProGetFeed -Session $ProGetSession -Force
}

Describe 'New-ProGetFeed.create a new Universal package feed' {
    
    $session = New-ProGetTestSession
    Initialize-ProGetFeedTests -ProGetSession $session

    New-ProGetFeed -Session $session -Type 'Universal' -Name 'FeedTest'
    $feedExists = Test-ProGetFeed -Session $session -Type 'Universal' -Name 'FeedTest'
    
    It 'should write no errors' {
        $Global:Error | Should BeNullOrEmpty
    }
    
    It 'should create a new ProGet universal feed' {
        $feedExists | Should Be $true
    }
}

Describe 'New-ProGetFeed.when attempting to create a duplicate package feed' {
        
    $session = New-ProGetTestSession
    Initialize-ProGetFeedTests -ProGetSession $session

    New-ProGetFeed -Session $session -Type 'Universal' -Name 'FeedTest'
    New-ProGetFeed -Session $session -Type 'Universal' -Name 'FeedTest' -ErrorAction SilentlyContinue
    
    It 'should write an error that the duplicate feed already exists' {
        $Global:Error | Should Match 'A feed with that name and type already exists'
    }
}

Describe 'New-ProGetFeed.when creating a duplicate package feed while ignoring errors' {
        
    $session = New-ProGetTestSession
    Initialize-ProGetFeedTests -ProGetSession $session
    
    New-ProGetFeed -Session $session -Type 'Universal' -Name 'FeedTest'
    New-ProGetFeed -Session $session -Type 'Universal' -Name 'FeedTest' -ErrorAction Ignore
    
    It 'should write no errors' {
        $Global:Error | Should BeNullOrEmpty
    }
}

Describe 'New-ProGetFeed.if session object contains an invalid API key' {
        
    $session = New-ProGetTestSession
    Initialize-ProGetFeedTests -ProGetSession $session
    $session.ApiKey = '==InvalidAPIKey=='
   
    New-ProGetFeed -Session $session -Type 'Universal' -Name 'FeedTest' -ErrorAction SilentlyContinue
    
    It 'should write an error if the specified API key is invalid' {
        $Global:Error | Should Match 'Use of the native API is forbidden with the specified API key'
    }
}

Describe 'New-ProGetFeed.if session object does not contain an API key' {
        
    $session = New-ProGetTestSession
    Initialize-ProGetFeedTests -ProGetSession $session
    $session.ApiKey = $null
    
    New-ProGetFeed -Session $session -Type 'Universal' -Name 'FeedTest' -ErrorAction SilentlyContinue
    
    It 'should write an error if no API key is specified' {
        $Global:Error | Should Match 'This function uses ProGet''s Native API, which requires an API key.'
    }
}

Describe 'New-ProGetFeed.if specified feed type is invalid' {
    
    $session = New-ProGetTestSession
    Initialize-ProGetFeedTests -ProGetSession $session

    New-ProGetFeed -Session $session -Type 'InvalidFeedType' -Name 'FeedTest' -ErrorAction SilentlyContinue
    
    It 'should write an error if feed type parameter contains undefined value' {
        $Global:Error | Should Match 'The INSERT statement conflicted with the CHECK constraint "CK__Feeds__FeedType_Name"'
    }
}
