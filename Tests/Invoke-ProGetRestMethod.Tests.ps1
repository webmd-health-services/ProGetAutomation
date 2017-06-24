
#Requires -Version 4
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

$session = New-ProGetTestSession
Describe 'Invoke-ProGetRestMethod.when making a GET request' {
    
    New-ProGetFeed -ProGetSession $session -FeedName 'Fubar' -FeedType 'ProGet' -ErrorAction Ignore

    $Global:Error.Clear()

    # This failed in early versions of the module.
    It 'should not throw an error' {
        { Invoke-ProGetRestMethod -Session $session -Method Get -Path ('/upack/Fubar/versions') } | Should -Not -Throw
    }

    It 'should not write any errors' {
        $Global:Error | Should -BeNullOrEmpty
    }

}