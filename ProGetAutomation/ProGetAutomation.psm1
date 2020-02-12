
Add-Type -AssemblyName 'System.Net.Http'
Add-Type -AssemblyName 'System.Web'
Add-Type -AssemblyName 'System.IO.Compression.FileSystem'

$functionsDirPath = Join-Path -Path $PSScriptRoot -ChildPath 'Functions'
if( (Test-Path -Path $functionsDirPath -PathType Container) )
{
    foreach( $item in Get-ChildItem -Path $functionsDirPath -Filter '*.ps1' )
    {
        Write-Debug -Message $item.FullName
        . $item.FullName
    }
}
