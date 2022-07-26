[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $ModsPath,

    [Parameter()]
    [string]
    $Use7Zip
)


<#
    .DESCRIPTION
    The Get-7ZipVersion function returns the version and architecture of 7z.exe execution,
    which is given in SevenZipPath parameter.
#>
function Get-7ZipVersion {
    param (
        [Parameter()]
        [string]
        $SevenZipPath
    )

    $result = [PSCustomObject]@{
        Available = $false
        Architecture = $null
        Path = $null
        Version = $null
    }

    $sevenZipMatch = $null
    try {
        $sevenZipMatch = (& $SevenZipPath | Select-String -Pattern "7-Zip").Line -match '7-Zip (?<ver>\d+\.\d+) \((?<arch>\w+)\)'
    }
    catch [System.Management.Automation.CommandNotFoundException] {
        throw $_
    }

    if ($sevenZipMatch) {
        $result.Available = $true
        $result.Architecture = $Matches.arch
        $result.Path = $($(Get-Command $SevenZipPath).Path)
        $result.Version = $Matches.ver
    }
    
    return $result
}






function Backup-TPFMods {
    
}

Backup-TPFMods

