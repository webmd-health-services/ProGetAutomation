
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath '..\ProGetAutomation\Import-ProGetAutomation.ps1' -Resolve)

$packageInfo = $null

$edition = ''
if( $PSVersionTable.ContainsKey('PSEdition') )
{
    $edition = '; {0}' -f $PSVersionTable.PSEdition
}
$expectedCreatedBy = 'ProGetAutomation/{0} (PowerShell {1}{2})' -f (Get-Module -Name 'ProGetAutomation').Version,$PSVersionTable.PSVersion,$edition

function GivenFile
{
    param(
        [string[]]
        $Path
    )

    foreach( $pathItem in $Path )
    {
        $fullPath = Join-Path -Path $TestDrive.FullName -ChildPath $pathItem

        $parentDir = $fullPath | Split-Path
        if( -not (Test-Path -Path $parentDir -PathType Container) )
        {
            New-Item -Path $parentDir -ItemType 'Directory'
        }

        if( -not (Test-Path -Path $fullPath -PathType Leaf) )
        {
            New-Item -Path $fullPath -ItemType 'File'
        }
    }
}

function Init
{
    $script:packageInfo = $null
}

function ThenError
{
    param(
        $Matches
    )

    It ('should write an error') {
        $Global:Error | Should -Match $Matches
    }
}

function ThenPackage
{
    param(
        [hashtable]
        $HasMetadata
    )

    It ('should create the package') {
        $packageInfo | Should -Exist
    }

    $packageExpandPath = Join-Path -Path $TestDrive.FullName -ChildPath ('upack.{0}.zip' -f [IO.Path]::GetRandomFileName())
    Expand-Archive -Path $packageInfo.FullName -DestinationPath $packageExpandPath

    $upackJsonPath = Join-Path -Path $packageExpandPath -ChildPath 'upack.json'
    It ('should set package metadata') {
        $upackJsonPath | Should -Exist
        $upackJson = Get-Content -Path $upackJsonPath -Raw | ConvertFrom-Json
        if( -not $HasMetadata.ContainsKey('createdDate') )
        {
            $HasMetadata['createdDate'] = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:*.*Z')
        }
        if( -not $HasMetadata.ContainsKey('createdUsing') )
        {
            $HasMetadata['createdUsing'] = $expectedCreatedBy
        }
        $parameterToPropertyMap = @{
                                        'groupName' = 'group';
                                        'dependency' = 'dependencies';
                                        'author' = 'createdBy';
                                        'reason' = 'createdReason';
                                        'tag' = 'tags';
                                   }
        foreach( $key in $HasMetadata.Keys )
        {
            $propertyName = $key
            if( $parameterToPropertyMap.ContainsKey($propertyName) )
            {
                $propertyName = $parameterToPropertyMap[$propertyName]
            }
            $member = $upackJson | Get-Member -Name $propertyName
            $member | Should -Not -BeNullOrEmpty -Because ('needs {0} property' -f $propertyName)
            $member.Name | Should -BeExactly $propertyName
            $value = $upackJson.$propertyName 
            if( $value -is [object[]] )
            {
                $value | Should -Be $HasMetadata[$key]
            }
            else
            {
                $value | Should -BeLike $HasMetadata[$key]
            }

        }
    }
}

function ThenPackageNotCreated
{
    param(
    )

    It ('should not create a package') {
        $packageInfo | Should -BeNullOrEmpty
    }
}

function WhenPackaging
{
    [CmdletBinding()]
    param(
        [hashtable]
        $WithParameters
    )

    $Global:Error.Clear()
    try
    {
        $script:packageInfo = New-ProGetUniversalPackage @WithParameters -OutFile (Join-Path -Path $TestDrive.FullName -ChildPath 'test.upack.zip')
    }
    catch
    {
        Write-Error -ErrorRecord $_
    }
}

Describe 'New-ProGetUniversalPackage.when packaging with minimum required metadata' {
    Init
    $metadata = @{ name = 'test' ; version = '0.0.0' }
    WhenPackaging -WithParameters $metadata
    ThenPackage -HasMetadata $metadata
}

Describe 'New-ProGetUniversalPackage.when packaging with all metadata' {
    Init
    $metadata = @{ 
                    name = 'test' ; 
                    version = '0.0.0';
                    groupName = 'ProGetAutomation';
                    title = 'Test';
                    projectUri = 'https://github.com/webmd-health-services/ProGetAutomation';
                    iconUri = 'https://github.com/webmd-health-services/ProGetAutomation/icon.png';
                    description = 'A test package for New-ProGetUniversalPackage';
                    tag = @( 'one', 'two', 'three' );
                    dependency = @( 'package', 'package2' );
                    reason = 'To test New-ProGetUniversalPackage';
                    author = 'some person';
                }
    WhenPackaging -WithParameters $metadata
    ThenPackage -HasMetadata $metadata
}

Describe 'New-ProGetUniversalPackage.when packaging with custom metadata' {
    Init
    $metadata = @{ 
                    name = 'test' ; 
                    version = '0.0.0';
                    AdditionalMetadata = @{ '_fubar' = 'snafu' }
                }
    WhenPackaging -WithParameters $metadata
    ThenPackage -HasMetadata @{ name = 'test' ; version = '0.0.0' ; '_fubar' = 'snafu' }
}

Describe 'New-ProGetUniversalPackage.when additional metadata contains parameters' {
    Init
    $metadata = @{ 
                    name = 'test' ; 
                    version = '0.0.0';
                    AdditionalMetadata = @{ 'name' = 'snafu' ; 'createdUsing' = 'Blah'; 'createdDate' = 'blah' }
                }
    WhenPackaging -WithParameters $metadata
    ThenPackage -HasMetadata @{ name = 'test' ; version = '0.0.0' ; 'createdUsing' = 'Blah'; 'createdDate' = 'blah' }
}

Describe 'New-ProGetUniversalPackage.when group name starts with a slash' {
    Init
    $metadata = @{ 
                    name = 'test' ; 
                    version = '0.0.0';
                    groupName = '/snafu';
                }
    WhenPackaging -WithParameters $metadata -ErrorAction SilentlyContinue
    ThenError -Matches 'does\ not\ match'
    ThenPackageNotCreated
}

Describe 'New-ProGetUniversalPackage.when group name ends with a slash' {
    Init
    $metadata = @{ 
                    name = 'test' ; 
                    version = '0.0.0';
                    groupName = 'snafu/';
                }
    WhenPackaging -WithParameters $metadata -ErrorAction SilentlyContinue
    ThenError -Matches 'does\ not\ match'
    ThenPackageNotCreated
}

Describe 'New-ProGetUniversalPackage.when group name contains invalid characters' {
    Init
    $metadata = @{ 
                    name = 'test' ; 
                    version = '0.0.0';
                    groupName = 'snafu fubar';
                }
    WhenPackaging -WithParameters $metadata -ErrorAction SilentlyContinue
    ThenError -Matches 'does\ not\ match'
    ThenPackageNotCreated
}

Describe 'New-ProGetUniversalPackage.when a tag contains invalid characters' {
    Init
    $metadata = @{ 
                    name = 'test' ; 
                    version = '0.0.0';
                    tag = @( 'one', 'two three' );
                }
    WhenPackaging -WithParameters $metadata -ErrorAction SilentlyContinue
    ThenError -Matches 'does\ not\ match'
    ThenPackageNotCreated
}

Describe 'New-ProGetUniversalPackage.when a name contains invalid characters' {
    Init
    $metadata = @{ 
                    name = 'test test' ; 
                    version = '0.0.0';
                }
    WhenPackaging -WithParameters $metadata -ErrorAction SilentlyContinue
    ThenError -Matches 'does\ not\ match'
    ThenPackageNotCreated
}