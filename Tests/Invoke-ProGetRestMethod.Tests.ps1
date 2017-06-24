
#Requires -Version 4
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

$session = New-ProGetTestSession
New-ProGetFeed -Session $session -FeedName 'Fubar' -FeedType 'ProGet' -ErrorAction Ignore

Describe 'Invoke-ProGetRestMethod.when making a GET request' {
    

    $Global:Error.Clear()

    # This failed in early versions of the module.
    It 'should not throw an error' {
        { Invoke-ProGetRestMethod -Session $session -Method Get -Path ('/upack/Fubar/versions') } | Should -Not -Throw
    }

    It 'should not write any errors' {
        $Global:Error | Should -BeNullOrEmpty
    }

}

Describe 'Invoke-ProGetRestMethod.when using credential in session' {
    $session = New-ProGetTestSession
    $session.Credential = New-Credential -UserName 'fubar' -Password 'snafu'

    Mock -CommandName 'Invoke-RestMethod' -ModuleName 'ProGetAutomation'

    Invoke-ProGetRestMethod -Session $session -Method Get -Path ('/upack/Fubar/versions')

    It 'should send credential to Invoke-RestMethod' {
        Assert-MockCalled -CommandName 'Invoke-RestMethod' -ModuleName 'ProGetAutomation' -ParameterFilter { $Credential -and $Credential.UserName -eq 'fubar' -and $Credential.GetNetworkCRedential().Password -eq 'snafu' }
    }
}

Describe 'Invoke-ProGetRestMethod.when not using a credential' {
    $session = New-ProGetTestSession
    $session.Credential = $null

    $Global:Error.Clear()

    It 'should not throw an error' {
        { Invoke-ProGetRestMethod -Session $session -Method Get -Path ('/upack/Fubar/versions') } | Should -Not -Throw
    }

    It 'should not write any errors' {
        $Global:Error | Should -BeNullOrEmpty
    }

} 