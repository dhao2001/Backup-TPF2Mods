[CmdletBinding(DefaultParameterSetName = 'BuildinCompress')]
param (
    [Parameter()]
    [string]
    $ModsPath,

    [Parameter()]
    [string]
    $BackupPath,

    [Parameter(ParameterSetName = 'BuildinCompress')]
    [switch]
    $UseBuildInCompress = $false,
    
    [Parameter(ParameterSetName = '7ZipCompress')]
    [string]
    $Use7Zip
)


<#
    Script scope variable used.
#>
$_use7zip = $null



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
            Join-Path $env:ProgramFiles -ChildPath '7-Zip' | Join-Path -ChildPath '7z'
            Join-Path ${env:ProgramFiles(x86)} -ChildPath '7-Zip' | Join-Path -ChildPath '7z'
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
    This `Start-ModsBackup` function creates backup of
    mods installed in specified directory.

    .PARAMETER DestinationPath
    Path to directory where backups of mods store.

    .PARAMETER ModsPath
    Path to `mods` of Transport Fever. There are 3 locations which
    may be provided to this parameter. 
    - Steam Workshop items' directory of Transport Fever, which is
      like `<SteamLibrary>\steamapps\workshop\content\1066780`.
    - Steam User directory of mods, which is something like
      `C:\Program Files (x86)\Steam\userdata\<steam_id>\1066780\local\mods`.
    - Transport Fever vanilla `mods` folder, like 
      `<SteamLibrary>\steamapps\common\Transport Fever 2\mods`, or
      just the `mods` folder in the same location as `TransportFever2.exe`

    .PARAMETER CompressMethod
    Decide the method to use for creating archive. 
    Acceptable values:
    - Buildin (Default): Use Powershell buildin `Compress-Archive`
      function to create *.zip* archive, which is faster than 
      using 7-Zip, while the archive is usually much larger.
    - 7Zip: Use 7-Zip to create archive with higher compression ratio,
      while it may be slower and lead to higher CPU and memory usage.
#>
function Start-ModsBackup {
    param (
        [Parameter(
            Mandatory,
            Position = 0
        )]
        [Alias('Destination')]
        [ValidateNotNullOrEmpty()]
        [string]
        $DestinationPath,
        
        [Parameter(
            Mandatory,
            Position = 1
        )]
        [Alias('Mods')]
        [ValidateNotNullOrEmpty()]
        [string]
        $ModsPath,

        [Parameter()]
        [ValidateSet('7Zip', 'Buildin')]
        [string]
        $CompressMethod = 'Buildin'
    )
    
    # Save current location to restore when finished.
    $curLocation = Get-Location

    # Create destination directory if not exist.
    if ( -not (Test-Path -Path $DestinationPath)) {
        New-Item -Path $DestinationPath -ItemType Directory
    }

    # Resolve the absolute path to destination directory.
    $abDestParent = Resolve-Path $DestinationPath

    # Resolve the absolute path to folder containing mods.
    $abModsPath = Resolve-Path $ModsPath

    # 7-Zip store directories in archive with the name of
    # relative path to current working directory. To make
    # the name conciser, changing working directory. 
    Set-Location $abModsPath

    # Get installed mods list in specified path.
    $mods = Get-ChildItem -Directory

    # Create list for storing mods to be backup.
    # And some counter.
    $modsToBackup = [System.Collections.Generic.List[PSObject]]::new()
    $modsSkippedCounter = 0
    $modsOverallCounter = 0

    # First scan all mods, generate target backup filename,
    # and check if backup of the same timestamp exists.
    foreach ($mod in $mods) {
        # Get the time of the mod's last modification.
        $modLastWrite = $mod.LastWriteTime

        # Choose extension according to compress method
        $backupExt = if ($CompressMethod -eq '7Zip') { "7z" } elseif ($CompressMethod -eq 'Buildin') { "zip" }

        # Generate backup file target filename
        $backupFilename = Join-Path $abDestParent "$($mod.Name)_$("{0:yyyyMMdd-HHmmss}" -f $($modLastWrite)).$($backupExt)"

        # Test if this backup has already been there.
        # If not, add to list for later backup process.
        # Otherwise, continue to next mod.
        if (-not (Test-Path -Path $backupFilename)) {
            $modsToBackup.Add([PSCustomObject]@{
                    Name           = $mod.Name
                    BackupFilename = $backupFilename
                })
        }
        else {
            $modsSkippedCounter++
        }

        $modsOverallCounter++
    }

    # Print skipping info.
    Write-Output "Found $($modsOverallCounter) mods. Skipping $($modsSkippedCounter) for existed backup. Backing up $($modsToBackup.Count)."


    # Do the main backup loop.
    for ($modBackupPtr = 0; $modBackupPtr -lt $modsToBackup.Count; $modBackupPtr++) {
        # Extract mod name and backup filename
        $modName = $modsToBackup[$modBackupPtr].Name
        $modBackupFilename = $modsToBackup[$modBackupPtr].BackupFilename

        # Show progress
        $progress = @{
            Activity         = "Creating Backup"
            Status           = "`($($modBackupPtr + 1)/$($modsToBackup.Count)`) $($modName) -> $(Split-Path -Path $modBackupFilename -Leaf)"
            # CurrentOperation = "Backup $($modName) -> $(Split-Path -Path $modBackupFilename -Leaf)"
            PercentComplete  = $($($modBackupPtr + 1) / $($modsToBackup.Count) * 100)
        }
        Write-Progress @progress

        # Use 7Zip to create *.7z* archive
        if ($CompressMethod -eq '7Zip') {
            $sz = $null
            if ($script:_use7zip -and $script:_use7zip.Available) {
                $sz = $script:_use7zip.Path
            }
            else {
                throw 'No available 7-Zip while asked to use it.'
            }
            $szOutput = & $sz a $modBackupFilename $modName

            if ($LASTEXITCODE -ne 0) {
                throw "Error occured when creating backup for $($mod.Name) modified at $($lastWrite)`n7-Zip Output:`n$($szOutput)"
            }
        }
        # Use Powershell buildin function to create *.zip* archive
        elseif ($CompressMethod -eq 'Buildin') {
            Compress-Archive -Path $modName -DestinationPath $modBackupFilename -ErrorAction Stop
        }
    }

    # Restore the working directory.
    Set-Location $curLocation
}





# Main Process Block

# Get current platform for later 7-Zip detection
$platform = Get-Platform

# Setting compress method
switch ($PSCmdlet.ParameterSetName) {
    # Default Parameter Set
    'BuildinCompress' { 
        # If `UseBuildInCompress` parameter is set, it indicates that user
        # force to use buildin compress. Do as user want.
        # If not set, search 7-Zip if available. Otherwise use
        # buildin compress.
        if ((-not $UseBuildInCompress) -and (($sevenZipVer = Get-System7ZipVersion $platform) -and $sevenZipVer.Available)) {
            $_use7zip = $sevenZipVer
            Write-Output "Using System 7-Zip $($sevenZipVer.Version) at $($sevenZipVer.Path)"
        }
        else {
            $_use7zip = $null
            Write-Output 'Using buildin compress.'
        }
    }

    # Detect 7-Zip when it is given by user.
    '7ZipCompress' {
        if ((-not [string]::IsNullOrWhiteSpace($Use7Zip)) -and (($sevenZipVer = Get-7ZipVersion $Use7Zip) -and $sevenZipVer.Available)) {
            $_use7zip = $sevenZipVer
            Write-Output "Using User's 7-Zip $($sevenZipVer.Version) at $($sevenZipVer.Path)"
        }
        else {
            throw "Invalid 7-Zip $Use7Zip was given."
        }
    }
    Default {
        $_use7zip = $null
    }
}

# Prepare backup parameters
$backupParam = @{
    DestinationPath = $BackupPath
    ModsPath        = $ModsPath
}

# Choose compress method
$backupParam.CompressMethod = if ($_use7zip.Available) { '7Zip' } else { 'Buildin' }

# Start backup
Start-ModsBackup @backupParam

Write-Output 'Finished.'