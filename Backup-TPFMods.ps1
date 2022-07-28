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
    Utilities
#>

enum HostPlatform {
    Windows
    Unix
}

function Get-Platform {
    if (!$PSVersionTable.Platform -or $PSVersionTable.Platform -eq 'Win32NT') {
        return [HostPlatform]::Windows
    }
    elseif ($PSVersionTable.Platform -eq 'Unix') {
        return [HostPlatform]::Unix
    }
}



<#
    Functions related to 7-Zip.
#>


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
        Available    = $false
        Architecture = $null
        Path         = $null
        Version      = $null
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
    This `Get-System7ZipVersion` function searches 7-Zip executable 
    in different locations by following order:

    1. Directory where this script exists.
    2. Directories in *PATH*
    3. Directory where 7-Zip usually installed, especially on Windows.

    This function searches for aliases to 7-Zip as follow:

    - Windows: `7z` for installation version, and `7za` for 
      standAlone version (according to 7-Zip official release).
    - Linux: `7zz` provided by Igor Pavlov or package `7zip` on
      Debian 12(bookworm) / Ubuntu 22.04 or later

#>
function Get-System7ZipVersion {
    param (
        [Parameter(Mandatory)]
        [ValidateSet('Windows', 'Unix')]
        [string]
        $Platform
    )

    $search7zPath = $null
    if ($Platform -eq 'Windows') {
        $search7zPath = @(
            Join-Path $PSScriptRoot '7za'
            Join-Path $PSScriptRoot '7z'
            '7za'
            '7z'
            Join-Path $env:ProgramFiles '7-Zip' '7z'
            Join-Path ${env:ProgramFiles(x86)} '7-Zip' '7z'
        )
    }
    elseif ($Platform -eq 'Unix') {
        $search7zPath = @(
            Join-Path $PSScriptRoot '7zz'
            Join-Path $PSScriptRoot '7z'
            '7zz'
            '7z'
            "/bin/7zz"
            "/usr/bin/7zz"
        )
    }
    foreach ($z in $search7zPath) {
        if ($c = Get-Command $z -ErrorAction SilentlyContinue) {
            $ver = Get-7ZipVersion -SevenZipPath $c.Path
            if ($ver.Available) {
                return $ver
            }
        }
    }
    return $ver
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





<#
    .DESCRIPTION
    This `Start-7ZipBackup` function creates a full backup of
    mods installed at Steam Workshop.

    .PARAMETER 7zPath
    Path to 7-Zip executable.

    .PARAMETER DestinationPath
    Path to directory where backups of mods store.

    .PARAMETER WorkshopModPath
    Path to Steam Workshop items' directory of Transport Fever.
    This path is similar to something like 
    `<SteamLibrary>\steamapps\workshop\content\1066780`, which is 
    the parent of ALL mods.
#>
function Start-7ZipBackup {
    param (
        # Specifies a path to one or more locations.
        [Parameter(
            Mandatory,
            Position = 0
        )]
        [Alias('7z')]
        [ValidateNotNullOrEmpty()]
        [string]
        $7zPath,

        [Parameter(
            Mandatory,
            Position = 1
        )]
        [Alias('Destination')]
        [ValidateNotNullOrEmpty()]
        [string]
        $DestinationPath,

        [Parameter(
            Mandatory,
            Position = 2
        )]
        [Alias('WorkshopMod')]
        [ValidateNotNullOrEmpty()]
        [string]
        $WorkshopModPath
    )
    
    $curLocation = Get-Location

    if ( -not (Test-Path -Path $DestinationPath)) {
        New-Item -Path $DestinationPath -ItemType Directory
    }
    $destParent = Resolve-Path $DestinationPath

    $modsParent = Resolve-Path $WorkshopModPath
    Set-Location $modsParent

    foreach ($mod in Get-ChildItem -Directory) {
        $lastWrite = $mod.LastWriteTime
        $destPath = Join-Path $destParent "$($mod.Name)_$("{0:yyyyMMdd-HHmmss}" -f $lastWrite).7z"
        if (Test-Path $destPath) {
            Write-Output "There is already a backup for $($mod.Name) modified at $($lastWrite). Skipping."
            continue
        }

        $7zOutput = & $7zPath 'a' $destPath $($mod.Name)
        if ($LASTEXITCODE -eq 0) {
            Write-Output "Backup for $($mod.Name) modified at $($lastWrite) is created."
        }
        else {
            throw "Error occured when creating backup for $($mod.Name) modified at $($lastWrite)`n7-Zip Output:`n$($7zOutput)"
        }
    }

    Set-Location $curLocation
}





<#
    .DESCRIPTION
    Main Function Block
#>
function Backup-TPFMods {
    $platform = Get-Platform
    if (-not [string]::IsNullOrWhiteSpace($script:Use7Zip)) {
        $7zver = Get-7ZipVersion $script:Use7Zip
        if ($7zver -and $7zver.Available) {
            Write-Output "Using User's 7-Zip $($7zver.Version) at $($7zver.Path)"
        }
    }
    elseif (($7zver = Get-System7ZipVersion $platform) -and $7zver.Available) {
        Write-Output "Using System 7-Zip $($7zver.Version) at $($7zver.Path)"
    }
    else {
        Write-Output "No available 7-Zip"
    }
}

Backup-TPFMods

