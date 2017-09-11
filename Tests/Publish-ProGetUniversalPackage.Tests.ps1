
#Requires -Version 4
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)

$packagePath = Join-Path -Path $PSScriptRoot -ChildPath '.\UniversalPackageTest-0.1.1.upack'
$packageName = 'UniversalPackageTest'
$feedName = 'Apps'

function Initialize-PublishProGetPackageTests
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]
        $ProGetSession
    )
    
    $Global:Error.Clear()

    # Remove all feeds from target ProGet instance
    $feeds = Invoke-ProGetNativeApiMethod -Session $ProGetSession -Name 'Feeds_GetFeeds' -Parameter @{IncludeInactive_Indicator = $true}
    if($feeds -match 'Feed_Id')
    {
        $feeds | ForEach-Object {
            Invoke-ProGetNativeApiMethod -Session $ProGetSession -Name 'Feeds_DeleteFeed' -Parameter @{Feed_Id = $PSItem.Feed_Id}
        }
    }
    
    New-ProGetFeed -Session $ProGetSession -FeedType 'ProGet' -FeedName $feedName
    $feedId = (Invoke-ProGetNativeApiMethod -Session $ProGetSession -Name 'Feeds_GetFeed' -Parameter @{Feed_Name = $feedName}).Feed_Id
    
    return $feedId
    
}

Describe 'Publish-ProGetUniversalPackage.publish a new Universal package' {
    
    $session = New-ProGetTestSession
    [String]$feedId = Initialize-PublishProGetPackageTests -ProGetSession $session
    
    Publish-ProGetUniversalPackage -Session $session -FeedName $feedName -PackagePath $packagePath
    $packageExists = Invoke-ProGetNativeApiMethod -Session $session -Name 'ProGetPackages_GetPackages' -Parameter @{Feed_Id = $feedId; Package_Name = $packageName}

    It 'should write no errors' {
        $Global:Error | Should BeNullOrEmpty
    }
    
    It 'should publish the package to the Apps universal package feed' {
        $packageExists | Should -Not -BeNullOrEmpty
    }
}

Describe 'Publish-ProGetUniversalPackage.publish an existing package' {
    
    $session = New-ProGetTestSession
    [String]$feedId = Initialize-PublishProGetPackageTests -ProGetSession $session

    Publish-ProGetUniversalPackage -Session $session -FeedName $feedName -PackagePath $packagePath
    Publish-ProGetUniversalPackage -Session $session -FeedName $feedName -PackagePath $packagePath -ErrorAction SilentlyContinue
    $packageExists = Invoke-ProGetNativeApiMethod -Session $session -Name 'ProGetPackages_GetPackages' -Parameter @{Feed_Id = $feedId; Package_Name = $packageName}

    It 'should write an error that package exists' {
        $Global:Error | Should -Match 'already exists'
    }
}

Describe 'Publish-ProGetUniversalPackage.when replacing an existing package' {
    
    $session = New-ProGetTestSession
    [String]$feedId = Initialize-PublishProGetPackageTests -ProGetSession $session

    Publish-ProGetUniversalPackage -Session $session -FeedName $feedName -PackagePath $packagePath
    Publish-ProGetUniversalPackage -Session $session -FeedName $feedName -PackagePath $packagePath -Force
    $packageExists = Invoke-ProGetNativeApiMethod -Session $session -Name 'ProGetPackages_GetPackages' -Parameter @{Feed_Id = $feedId; Package_Name = $packageName}

    It 'should replace the package' {
        $Global:Error | Should -BeNullOrEmpty
    }
}

Describe 'Publish-ProGetUniversalPackage.invalid credentials are passed' {
    
    $session = New-ProGetTestSession
    [String]$feedId = Initialize-PublishProGetPackageTests -ProGetSession $session
    $session.Credential = New-Credential -UserName 'Invalid' -Password 'Credentia'

    Publish-ProGetUniversalPackage -Session $session -FeedName $feedName -PackagePath $packagePath -ErrorAction SilentlyContinue
    $packageExists = Invoke-ProGetNativeApiMethod -Session $session -Name 'ProGetPackages_GetPackages' -Parameter @{Feed_Id = $feedId; Package_Name = $packageName}

    It 'should write an error that the action cannot be performed' {
        $Global:Error | Where-Object { $_ -match 'Failed to upload' } | Should -Not -BeNullOrEmpty
    }
    
    It 'should not publish the package to the Apps universal package feed' {
        $packageExists | Should Not Be $true
    }
}

Describe 'Publish-ProGetUniversalPackage.no credentials are passed' {
    
    $session = New-ProGetTestSession
    [String]$feedId = Initialize-PublishProGetPackageTests -ProGetSession $session
    $credential = $session.Credential
    $session.Credential = $null

    Publish-ProGetUniversalPackage -Session $session -FeedName $feedName -PackagePath $packagePath -ErrorAction SilentlyContinue

    $session.Credential = $credential
    $packageExists = Invoke-ProGetNativeApiMethod -Session $session -Name 'ProGetPackages_GetPackages' -Parameter @{Feed_Id = $feedId; Package_Name = $packageName}
    
    It 'should write an error that a PSCredential object must be provided' {
        $Global:Error | Where-Object { $_ -match 'Failed to upload' } | Should -Not -BeNullOrEmpty
        $Global:Error | Where-Object { $_ -match '401\ Unauthorized' } | Should -Not -BeNullOrEmpty
    } 
    
    It 'should not publish the package to the Apps universal package feed' {
        $packageExists | Should Not Be $true
    }
}

Describe 'Publish-ProGetUniversalPackage.specified target feed does not exist' {
    
    $session = New-ProGetTestSession
    [String]$feedId = Initialize-PublishProGetPackageTests -ProGetSession $session
    $feedName = 'InvalidAppFeed'

    Publish-ProGetUniversalPackage -Session $session -FeedName $feedName -PackagePath $packagePath -ErrorAction SilentlyContinue
    $packageExists = Invoke-ProGetNativeApiMethod -Session $session -Name 'ProGetPackages_GetPackages' -Parameter @{Feed_Id = $feedId; Package_Name = $packageName}

    It 'should write an error that the defined feed is invalid' {
        $Global:Error | Where-Object { $_ -match 'Failed to upload' } | Should -Not -BeNullOrEmpty
        $Global:Error | Where-Object { $_ -match '404\ NotFound' } | Should -Not -BeNullOrEmpty
    }
    
    It 'should not publish the package to the Apps universal package feed' {
        $packageExists | Should Not Be $true
    }
}

Describe 'Publish-ProGetUniversalPackage.package does not exist at specified package path' {
    
    $session = New-ProGetTestSession
    [String]$feedId = Initialize-PublishProGetPackageTests -ProGetSession $session
    $packagePath = '.\BadPackagePath'

    Publish-ProGetUniversalPackage -Session $session -FeedName $feedName -PackagePath $packagePath -ErrorAction SilentlyContinue
    $packageExists = Invoke-ProGetNativeApiMethod -Session $session -Name 'ProGetPackages_GetPackages' -Parameter @{Feed_Id = $feedId; Package_Name = $packageName}

    It 'should write an error that the package could not be found' {
        $Global:Error | Should Match 'does not exist'
    }
    
    It 'should not publish the package to the Apps universal package feed' {
        $packageExists | Should Not Be $true
    }
}

Describe 'Publish-ProGetUniversalPackage.when package isn''t a ZIP file' {
    $session = New-ProGetTestSession
    [String]$feedId = Initialize-PublishProGetPackageTests -ProGetSession $session
    Publish-ProGetUniversalPackage -Session $session -FeedName $feedName -PackagePath $PSCommandPath -ErrorAction SilentlyContinue
    $packageExists = Invoke-ProGetNativeApiMethod -Session $session -Name 'ProGetPackages_GetPackages' -Parameter @{Feed_Id = $feedId; }

    It ('should fail') {
        $Global:Error | Should -Not -BeNullOrEmpty
    }

    It ('should not publish the package') {
        $packageExists | Should -BeNullOrEmpty
    }
}

Describe 'Publish-ProGetUniversalPackage.when package contains invalid upack.json' {
    $session = New-ProGetTestSession
    [String]$feedId = Initialize-PublishProGetPackageTests -ProGetSession $session
    Publish-ProGetUniversalPackage -Session $session -FeedName $feedName -PackagePath (Join-Path -Path $PSScriptRoot -ChildPath 'UniversalInvalidUpackJson.upack') -ErrorAction SilentlyContinue
    $packages = Invoke-ProGetNativeApiMethod -Session $session -Name 'ProGetPackages_GetPackages' -Parameter @{Feed_Id = $feedId; }

    It ('should fail') {
        $Global:Error | Where-Object { $_ -match 'must be a valid JSON file' } | Should -Not -BeNullOrEmpty
    }

    It ('should not publish any packages') {
        $packages | Should -BeNullOrEmpty
    }
}

Describe 'Publish-ProGetUniversalPackage.when package contains no upack.json' {
    $session = New-ProGetTestSession
    [String]$feedId = Initialize-PublishProGetPackageTests -ProGetSession $session
    Publish-ProGetUniversalPackage -Session $session -FeedName $feedName -PackagePath (Join-Path -Path $PSScriptRoot -ChildPath 'UniversalNoUpackJson.upack') -ErrorAction SilentlyContinue
    $packages = Invoke-ProGetNativeApiMethod -Session $session -Name 'ProGetPackages_GetPackages' -Parameter @{Feed_Id = $feedId; }

    It ('should fail') {
        $Global:Error | Where-Object { $_ -match 'must contain a upack\.json' } | Should -Not -BeNullOrEmpty
    }

    It ('should not publish any packages') {
        $packages | Should -BeNullOrEmpty
    }
}

Describe 'Publish-ProGetUniversalPackage.when upack.json missing name and version properties' {
    $session = New-ProGetTestSession
    [String]$feedId = Initialize-PublishProGetPackageTests -ProGetSession $session
    Publish-ProGetUniversalPackage -Session $session -FeedName $feedName -PackagePath (Join-Path -Path $PSScriptRoot -ChildPath 'UniversalUpackJsonMissingNameAndVersion.upack') -ErrorAction SilentlyContinue
    $packages = Invoke-ProGetNativeApiMethod -Session $session -Name 'ProGetPackages_GetPackages' -Parameter @{Feed_Id = $feedId; }

    It ('should fail') {
        $Global:Error | Where-Object { $_ -match '''name'' and ''version''' } | Should -Not -BeNullOrEmpty
    }

    It ('should not publish any packages') {
        $packages | Should -BeNullOrEmpty
    }
}