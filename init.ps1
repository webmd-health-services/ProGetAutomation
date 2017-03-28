[CmdletBinding()]
param(
)

#Requires -Version 4
Set-StrictMode -Version 'Latest'

foreach( $moduleName in @( 'Pester', 'Carbon' ) )
{
    if( (Test-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath $moduleName) -PathType Container) )
    {
        break
    }

    Save-Module -Name $moduleName -Path '.' 
}

if (Get-Module -Name 'Carbon') {Remove-Module -Name 'Carbon'}
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'Carbon') -Force -Verbose:$false

$runningUnderAppVeyor = (Test-Path -Path 'env:APPVEYOR')

$version = '4.7.6'

$installerPath = Join-Path -Path $env:TEMP -ChildPath ('ProGetInstaller-SQL-{0}.exe' -f $version)
if( -not (Test-Path -Path $installerPath -PathType Leaf) )
{
    $uri = ('http://inedo.com/proget/download/sql/{0}' -f $version)
    Write-Verbose -Message ('Downloading {0}' -f $uri)
    Invoke-WebRequest -Uri $uri -OutFile $installerPath
}

$pgInstallInfo = Get-ProgramInstallInfo -Name 'ProGet'
if( -not $pgInstallInfo )
{
    $pgConnectionString = '/ConnectionString="Data Source=localhost\ProGet; Initial Catalog=ProGet; Integrated Security=True;"'
    $dbParam = '/InstallSqlExpress'
    $bmInstallInfo = Get-ProgramInstallInfo -Name 'BuildMaster'
    if ($bmInstallInfo) {
        Write-Verbose -Message 'BuildMaster is installed. ProGet will join existing SQL Server instance..'
        $bmConfigLocation = Join-Path -Path (Get-ItemProperty -Path 'HKLM:\Software\Inedo\BuildMaster').ServicePath -ChildPath 'app_appSettings.config'
    
        $xml = [xml](Get-Content -Path $bmConfigLocation) 
        $bmDbConfigSetting = $xml.SelectSingleNode("//add[@key = 'Core.DbConnectionString']")
        $bmConnectionString = $bmDbConfigSetting.Value.Substring(0,$bmDbConfigSetting.Value.IndexOf(';'))
        $pgConnectionString = ('/ConnectionString="{0};Initial Catalog=ProGet; Integrated Security=True;"' -f $bmConnectionString)
        $dbParam = '/InstallSqlExpress=False'
    }

    # Under AppVeyor, use the pre-installed database.
    # Otherwise, install a SQL Express ProGet instance.
    if( $runningUnderAppVeyor )
    {
        $dbParam = '"/ConnectionString=Server=(local)\SQL2016;Database=ProGet;User ID=sa;Password=Password12!"'
    }

    $outputRoot = Join-Path -Path $PSScriptRoot -ChildPath '.output'
    New-Item -Path $outputRoot -ItemType 'Directory' -ErrorAction Ignore

    $logRoot = Join-Path -Path $outputRoot -ChildPath 'logs'
    New-Item -Path $logRoot -ItemType 'Directory' -ErrorAction Ignore

    Write-Verbose -Message ('Running ProGet installer {0}.' -f $installerPath)
    $logPath = Join-Path -Path $logRoot -ChildPath 'proget.install.log'
    $installerFileName = $installerPath | Split-Path -Leaf
    $stdOutLogPath = Join-Path -Path $logRoot -ChildPath ('{0}.stdout.log' -f $installerFileName)
    $stdErrLogPath = Join-Path -Path $logRoot -ChildPath ('{0}.stderr.log' -f $installerFileName)
    $process = Start-Process -FilePath $installerPath `
                             -ArgumentList '/S','/Edition=Express',$pgConnectionString,$dbParam,('"/LogFile={0}"' -f $logPath),'/Port=82' `
                             -Wait `
                             -PassThru `
                             -RedirectStandardError $stdErrLogPath `
                             -RedirectStandardOutput $stdOutLogPath
    $process.WaitForExit()

    Write-Verbose -Message ('{0} exited with code {1}' -f $installerFileName, $process.ExitCode)

    if( -not (Get-ProgramInstallInfo -Name 'ProGet') )
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