
#Requires -Version 4
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

$session = New-ProGetTestSession
New-ProGetFeed -Session $session -Name 'Fubar' -Type 'ProGet' -ErrorAction Ignore

Describe 'Invoke-ProGetRestMethod.when making a GET request' {
    $Global:Error.Clear()

    It 'should not throw an error' {
        { Invoke-ProGetRestMethod -Session $session -Method Get -Path ('/upack/Fubar/versions') } | Should -Not -Throw
    }

    It 'should not write any errors' {
        $Global:Error | Should -BeNullOrEmpty
    }
}

Describe 'Invoke-ProGetRestMethod.when making a POST request with defined body content' {
    $Global:Error.Clear()

    Mock -CommandName 'Invoke-RestMethod' -ModuleName 'ProGetAutomation'
    
    It 'should not throw an error' {
        { Invoke-ProGetRestMethod -Session $session -Method Post -Path ('/upack/Fubar/versions') -Body 'xyz body content' } | Should -Not -Throw
    }

    It 'should not write any errors' {
        $Global:Error | Should -BeNullOrEmpty
    }

    It 'should send defined body content to Invoke-RestMethod' {
        Assert-MockCalled -CommandName 'Invoke-RestMethod' -ModuleName 'ProGetAutomation' -ParameterFilter { $Body -eq 'xyz body content' }
    }
}

Describe 'Invoke-ProGetRestMethod.when using credential in session' {
    $session = New-ProGetTestSession
    $session.Credential = New-Object 'pscredential' ('fubar',(ConvertTo-SecureString 'snafu' -AsPlainText -Force))

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

Describe 'Invoke-ProGetRestMethod.when using WhatIf' {
    $feedName = 'Invoke-ProGetRestMethod.Tests.ps1.WhatIf'
    Get-ProGetFeed -Session $session -Name $feedName | Remove-ProGetFeed -Session $session -Force
    New-ProGetFeed -Session $session -Name $feedName -Type 'ProGet'
    $package = New-ProGetUniversalPackage -OutFile (Join-Path -Path $TestDrive.FullName -ChildPath 'package.upack') -Version '0.0.0' -Name 'WhatIf'
    Publish-ProGetUniversalPackage -Session $session -FeedName $feedName -PackagePath $package.FullName
    Invoke-ProGetRestMethod -Session $Session -Path ('/upack/{0}/delete/WhatIf/0.0.0' -f $feedName) -Method Delete -WhatIf
    It ('should not make web request') {
        Get-ProGetUniversalPackage -Session $session -FeedName $feedName -Name 'WhatIf' | Should -Not -BeNullOrEmpty
    }

    
}