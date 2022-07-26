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
    Script scope variable used.
#>
$script:_use7zip = $false
$script:_7zipPath = $null


<#
    .DESCRIPTION
    The `Get-7ZipVersion` function returns the version and architecture of 7z.exe execution,
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
        $sevenZipMatch = (& $SevenZipPath | Select-String -Pattern "7-Zip").Line -match '7-Zip\s(?:\([az]\)\s)?(?<ver>\d+\.\d+)\s\((?<arch>\w+)\)'
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

<#
    .DESCRIPTION
    The `Use-7Zip‘ funcion sets the 7z.exe execution's path and flag in script scope.
#>
function Use-7Zip {
    param (
        [string]$SevenZipPath
    )

    $script:_use7zip = $true
    $script:_7zipPath = $SevenZipPath
}


function New-7ZipArchive {
    param (
        
    )

    & $script:_7zipPath
}



function Backup-TPFMods {
    if ( -not [string]::IsNullOrWhiteSpace($script:Use7Zip)) {
        $szVer = Get-7ZipVersion $script:Use7Zip
    }
    Write-Output $szVer
}

Backup-TPFMods

