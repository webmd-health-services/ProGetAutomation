[CmdletBinding()]
param(
)

#Requires -RunAsAdministrator
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& {
    $VerbosePreference = 'SilentlyContinue'
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'PSModules\Carbon') -Force
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'PSModules\SqlServer') -Force
}

$runningUnderAppVeyor = (Test-Path -Path 'env:APPVEYOR')

$version = '5.2.24'
Write-Verbose -Message ('Testing ProGet {0}' -f $version)
$sqlServer = $null
$installerPath = 'SQL'
$installerUri = 'sql'
$dbParam = '/InstallSqlExpress'

$sqlServers = @()
if( (Test-Path -Path 'env:APPVEYOR') )
{
    $sqlServers = Get-Item -Path ('SQLSERVER:\SQL\{0}\SQL2017' -f [Environment]::MachineName)
}
else
{
    $sqlServers = Get-ChildItem -Path ('SQLSERVER:\SQL\{0}' -f [Environment]::MachineName)
}

foreach( $item in $sqlServers )
{
    if( $item.Status -ne [Microsoft.SqlServer.Management.Smo.ServerStatus]::Online )
    {
        Write-Verbose -Message ('Skipping SQL Server instance "{0}": "{1}".' -f $item.Name,$item.Status)
        continue
    }

    $item | Format-List | Out-String | Write-Verbose

    if( -not $item.InstanceName -or $item.InstanceName -in @( 'Inedo', 'SQL2017' ) )
    {
        Write-Verbose -Message ('Found SQL Server instance "{0}": "{1}".' -f $item.Name,$item.Status)
        $installerPath = 'NO{0}' -f $installerPath
        $installerUri = 'no{0}' -f $installerUri
        $sqlServer = $item
        $credentials = 'Integrated Security=true;'
        if( $runningUnderAppVeyor )
        {
            $credentials = 'User ID=sa;Password=Password12!'
        }
        $dbParam = '"/ConnectionString=Server={0};Database=ProGet;{1}"' -f $sqlServer.Name,$credentials
        break
    }
}

$installerPath = Join-Path -Path $PSScriptRoot -ChildPath ('.output\ProGetIntaller{0}-{1}.exe' -f $installerPath,$version)
if( -not (Test-Path -Path $installerPath -PathType Leaf) )
{
    $uri = ('http://inedo.com/proget/download/sql/{0}' -f $version)
    Write-Verbose -Message ('Downloading {0}' -f $uri)
    Invoke-WebRequest -Uri $uri -OutFile $installerPath
}

$pgInstallInfo = Get-CProgramInstallInfo -Name 'ProGet'
if( -not $pgInstallInfo )
{
    $outputRoot = Join-Path -Path $PSScriptRoot -ChildPath '.output'
    New-Item -Path $outputRoot -ItemType 'Directory' -ErrorAction Ignore

    $logRoot = Join-Path -Path $outputRoot -ChildPath 'logs'
    New-Item -Path $logRoot -ItemType 'Directory' -ErrorAction Ignore

    Write-Verbose -Message ('Running ProGet installer {0}.' -f $installerPath)
    $logPath = Join-Path -Path $logRoot -ChildPath 'proget.install.log'
    $installerFileName = $installerPath | Split-Path -Leaf
    $stdOutLogPath = Join-Path -Path $logRoot -ChildPath ('{0}.stdout.log' -f $installerFileName)
    $stdErrLogPath = Join-Path -Path $logRoot -ChildPath ('{0}.stderr.log' -f $installerFileName)
    $argumentList = '/S','/Edition=Express',$dbParam,('"/LogFile={0}"' -f $logPath)
    Write-Verbose ('{0} {1}' -f $installerPath,($argumentList -join ' '))
    $process = Start-Process -FilePath $installerPath `
                             -ArgumentList $argumentList `
                             -Wait `
                             -PassThru `
                             -RedirectStandardError $stdErrLogPath `
                             -RedirectStandardOutput $stdOutLogPath
    $process.WaitForExit()

    Write-Verbose -Message ('{0} exited with code {1}' -f $installerFileName,$process.ExitCode)

    if( -not (Get-CProgramInstallInfo -Name 'ProGet') )
    {
        if( $runningUnderAppVeyor )
        {
            Get-ChildItem -Path $logRoot |
                ForEach-Object {
                    $_
                    $_ | Get-Content
                }
        }
        Write-Error -Message ('It looks like ProGet {0} didn''t install. The install log might have more information: {1}' -f $version, $logPath)
    }
}
elseif( $pgInstallInfo.DisplayVersion -notmatch ('^{0}\b' -f [regex]::Escape($version)) )
{
    Write-Warning -Message ('You''ve got an old version of ProGet installed. You''re on version {0}, but we expected version {1}. Please *completely* uninstall version {0} using the Programs and Features control panel, then re-run this script.' -f $pgInstallInfo.DisplayVersion, $version)
}

Get-Service -Name 'InedoProget*' | Start-Service