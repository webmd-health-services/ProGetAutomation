
& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

$uri = 'https://proget.test.uri'
$uName = 'Test'
$PWord = 'User'
$apiKey = '==TestAPIKey'
$credential = New-Object 'pscredential' ('Test',(ConvertTo-SecureString 'User' -AsPlainText -Force))

Describe 'New-ProGetSession.when passed credentials and an API key' {
        
    $session = New-ProGetSession -Uri $uri -Credential $credential -ApiKey $apiKey 

    It 'should return session object' {
        $session | Should Not BeNullOrEmpty
    }

    It 'should set URI' {
        $session.Uri | Should Be ([uri]$uri)
    }

    It 'should contain a valid credential username' {
        $session.Credential.UserName | Should Be $uName
    }

    It 'should contain a valid encrypted credential password' {
        $session.Credential.GetNetworkCredential().Password | Should Be $pWord
    }

    It 'should contain a valid API key' {
        $session.ApiKey | Should Be $apiKey
    }
}

Describe 'New-ProGetSession.when passed credentials and not an API key' {
        
    $session = New-ProGetSession -Uri $uri -Credential $credential

    It 'should return session object' {
        $session | Should Not BeNullOrEmpty
    }

    It 'should set URI' {
        $session.Uri | Should Be ([uri]$uri)
    }

    It 'should contain a valid credential username' {
        $session.Credential.UserName | Should Be $uName
    }

    It 'should contain a valid encrypted credential password' {
        $session.Credential.GetNetworkCredential().Password | Should Be $pWord
    }

    It 'should not contain an API key' {
        $session.ApiKey | Should BeNullOrEmpty
    }
}

Describe 'New-ProGetSession.when passed an API key and no credentials' {
        
    $session = New-ProGetSession -Uri $uri -ApiKey $apiKey

    It 'should return session object' {
        $session | Should Not BeNullOrEmpty
    }

    It 'should set URI' {
        $session.Uri | Should Be ([uri]$uri)
    }

    It 'should not contain username or password credentials' {
        $session.Credential | Should BeNullOrEmpty
    }
    
    It 'should contain a valid API key' {
        $session.ApiKey | Should Be $apiKey
    }
}
