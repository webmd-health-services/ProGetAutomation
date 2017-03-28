
& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Tests.ps1' -Resolve)


$packagePath = '.\WhsUniversalPackageTest-0.1.1.upack'
$packageName = 'WhsUniversalPackageTest'
$feedName = 'Apps'

function Initialize-PublishPGPackageTests
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]
        $ProGetSession
    )
    
    $Global:Error.Clear()

     # Remove all feeds from target ProGet instance
    Invoke-PGNativeApiMethod -Session $ProGetSession -Name 'Feeds_GetFeeds' -Parameter @{IncludeInactive_Indicator = $true} |
        ForEach-Object { 
            Invoke-PGNativeApiMethod -Session $ProGetSession -Name 'Feeds_DeleteFeed' -Parameter @{Feed_Id = $PSItem.Feed_Id}
        }
    
    New-ProGetFeed -ProGetSession $ProGetSession -FeedType 'ProGet' -FeedName $feedName
    $feedId = (Invoke-PGNativeApiMethod -Session $ProGetSession -Name 'Feeds_GetFeed' -Parameter @{Feed_Name = $feedName}).Feed_Id
    
    return $feedId
    
}

Describe 'Publish-ProGetUniversalPackage.publish a new Universal package' {
    
    $session = New-ProGetTestSession
    [String]$feedId = Initialize-PublishPGPackageTests -ProGetSession $session
    
    Publish-ProGetUniversalPackage -ProGetSession $session -FeedName $feedName -PackagePath $packagePath
    $packageExists = Invoke-PGNativeApiMethod -Session $session -Name 'ProGetPackages_GetPackages' -Parameter @{Feed_Id = $feedId; Package_Name = $packageName}

    It 'should write no errors' {
        $Global:Error | Should BeNullOrEmpty
    }
    
    It 'should publish the package to the Apps universal package feed' {
        $packageExists | Should Be $true
    }
}

Describe 'Publish-ProGetUniversalPackage.invalid credentials are passed' {
    
    $session = New-ProGetTestSession
    [String]$feedId = Initialize-PublishPGPackageTests -ProGetSession $session
    $session.Credential = New-Credential -UserName 'Invalid' -Password 'Credentia'

    try
    {
        Publish-ProGetUniversalPackage -ProGetSession $session -FeedName $feedName -PackagePath $packagePath
    }
    catch
    {
    }
    $packageExists = Invoke-PGNativeApiMethod -Session $session -Name 'ProGetPackages_GetPackages' -Parameter @{Feed_Id = $feedId; Package_Name = $packageName}

    It 'should write an error that the action cannot be performed' {
        $Global:Error | Should Match 'The Feeds_AddPackage task is required to perform this action.'
    }
    
    It 'should not publish the package to the Apps universal package feed' {
        $packageExists | Should Not Be $true
    }
}

Describe 'Publish-ProGetUniversalPackage.no credentials are passed' {
    
    $session = New-ProGetTestSession
    [String]$feedId = Initialize-PublishPGPackageTests -ProGetSession $session
    $session.Credential = $null

    try
    {
        Publish-ProGetUniversalPackage -ProGetSession $session -FeedName $feedName -PackagePath $packagePath
    }
    catch
    {
    }
    $packageExists = Invoke-PGNativeApiMethod -Session $session -Name 'ProGetPackages_GetPackages' -Parameter @{Feed_Id = $feedId; Package_Name = $packageName}

    It 'should write an error that a PSCredential object must be provided' {
        $Global:Error | Should Match '''ProGetSession'' parameter must contain a PSCredential object with a user name and password.'
    }
    
    It 'should not publish the package to the Apps universal package feed' {
        $packageExists | Should Not Be $true
    }
}

Describe 'Publish-ProGetUniversalPackage.specified target feed does not exist' {
    
    $session = New-ProGetTestSession
    [String]$feedId = Initialize-PublishPGPackageTests -ProGetSession $session
    $feedName = 'InvalidAppFeed'

    try
    {
        Publish-ProGetUniversalPackage -ProGetSession $session -FeedName $feedName -PackagePath $packagePath
    }
    catch
    {
    }
    $packageExists = Invoke-PGNativeApiMethod -Session $session -Name 'ProGetPackages_GetPackages' -Parameter @{Feed_Id = $feedId; Package_Name = $packageName}

    It 'should write an error that the defined feed is invalid' {
        $Global:Error | Should Match ('Invalid feed: {0}' -f $feedName)
    }
    
    It 'should not publish the package to the Apps universal package feed' {
        $packageExists | Should Not Be $true
    }
}

Describe 'Publish-ProGetUniversalPackage.package does not exist at specified package path' {
    
    $session = New-ProGetTestSession
    [String]$feedId = Initialize-PublishPGPackageTests -ProGetSession $session
    $packagePath = '.\BadPackagePath'

    try
    {
        Publish-ProGetUniversalPackage -ProGetSession $session -FeedName $feedName -PackagePath $packagePath
    }
    catch
    {
    }
    $packageExists = Invoke-PGNativeApiMethod -Session $session -Name 'ProGetPackages_GetPackages' -Parameter @{Feed_Id = $feedId; Package_Name = $packageName}

    It 'should write an error that the package could not be found' {
        $Global:Error | Should Match 'Could not find file'
    }
    
    It 'should not publish the package to the Apps universal package feed' {
        $packageExists | Should Not Be $true
    }
}
