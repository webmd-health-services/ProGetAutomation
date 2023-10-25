
using namespace Microsoft.PowerShell.Commands
using namespace System.IO
using namespace System.IO.Compression
using namespace System.Net.Http
using namespace System.Net.Http.Headers
using namespace System.Text
using namespace System.Threading
using namespace System.Threading.Tasks
using namespace System.Web

Add-Type -AssemblyName 'System.Net.Http'
Add-Type -AssemblyName 'System.Web'
Add-Type -AssemblyName 'System.IO.Compression.FileSystem'

$privateModules = Join-Path -Path $PSScriptRoot -ChildPath 'Modules'
Import-Module -Name (Join-Path -Path $privateModules -ChildPath 'Zip') `
              -Function @('Add-ZipArchiveEntry', 'New-ZipArchive')

$functionsDirPath = Join-Path -Path $PSScriptRoot -ChildPath 'Functions'
if( (Test-Path -Path $functionsDirPath -PathType Container) )
{
    foreach( $item in Get-ChildItem -Path $functionsDirPath -Filter '*.ps1' )
    {
        Write-Debug -Message $item.FullName
        . $item.FullName
    }
}
