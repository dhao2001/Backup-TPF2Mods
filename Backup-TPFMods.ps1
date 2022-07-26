[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $ModsPath,

    [Parameter()]
    [string]
    $Use7Zip
)

function get-7z-availability {
    param (
        [Parameter()]
        [string]
        $sevenZipPath
    )

    $result = [PSCustomObject]@{
        Available = $false
        Version = $null
        Architecture = $null
    }

    $sevenZipMatch = $null
    try {
        $sevenZipMatch = (& $sevenZipPath | Select-String -Pattern "7-Zip").Line -match '7-Zip (?<ver>\d+\.\d+) \((?<arch>\w+)\)'
    }
    catch [System.Management.Automation.CommandNotFoundException] {
        throw $_
    }

    if ($sevenZipMatch) {
        $result.Version = $Matches.ver
        $result.Architecture = $Matches.arch
        $result.Available = $true
    }
    
    return $result
}






function Backup-TPFMods {
    
}

Backup-TPFMods

