# Transport Fever Mods Backup Script

A powershell script for backing up mods of Transport Fever 1/2, especially for Steam Workshop items. 

## Requirement

This is a Powershell script, and it means to work on various platforms with a supported version Powershell installed. More specially, these platforms should work fine.

- Windows (7 or later, with *Windows Powershell* feature enabled. Most Transport Fever player's environment have already met this requirement.)
- Windows (7 or later, with *Powershell Core 6+ / Powershell 7* installed)
- Linux with *Powershell Core 6+ / Powershell 7* installed

For now, this script rely on [7-Zip](https://www.7-zip.org/) to create new archive. More detail is described below. Thanks to Igor Pavlov and other 7-Zip contributors.


## Install

Just download the `Backup-TPFMods.ps1` files and save it to your disk, or copy the content of this file and paste it to a new plaintext file, with `.ps1` extension.


## 7-Zip

### For Simple

For most Transport Fever players, who play Transport Fever on their Windows PC, the simplest way to have a woking 7-Zip is to download a installer from [7-Zip](https://www.7-zip.org/) and install it to default location, and `Backup-TPFMods` script will care about the rest. It is a free and open source file archiver that worth to use.

### For Advanced User

For those who want to take everything in control, to play Transport Fever on Linux, or just not like to install a extra software, you can pick a solution below to let this script find a runnable 7-Zip.

- (Recommended) Specify the path to your 7-Zip executable by parameter `-Use7Zip`, describe as below.
- Put a standalone 7-Zip executable to the same directory where this script file exists on your filesystem.
- Put a standalone 7-Zip executable to a location included in `PATH` environment variable, or add your 7-Zip installation directory to your `PATH`.
- *On Windows only*, install 7-Zip to the default location of official installer, that is `%ProgramFiles%\7-Zip` or `%ProgramFiles(x86)%\7-Zip`.
- *On Linux only*, install `7zip` package which provides `7zz` executable in `$PATH`. Note that as for 2022 Q2, **ONLY** the repository of Debian 12/sid and Ubuntu 22.04 provide `7zip` package. **`p7zip` is currently NOT COMPATIBLE!**

Executable with following names are searched for.

- `7za` (Windows)
- `7zz` (Linux)
- `7z`


## How to Use

```
.\Backup-TPFMods.ps1 -BackupPath <path-to-store-backup-archive> -ModsPath <path-to-mods-folder> [-Use7Zip <path-to-7z-executable>]
```

### Example

Running this script as below will save each mod installed in `Y:\SteamLibrary\steamapps\workshop\content\1066780` into a seperate *.7z* archive at `X:\MyTPFBackup`, using 7-Zip executable at `Z:\7-Zip\7z.exe`.

```powershell
PS X:\Some\Position> .\Backup-TPFMods.ps1 -BackupPath X:\MyTPFBackup -ModsPath Y:\SteamLibrary\steamapps\workshop\content\1066780 -Use7Zip Z:\7-Zip\7z.exe
```

### Output

The archive of mods are named by following rules.

```
<mod_workshop_item_id>_<last_write_timestamp>.7z
```

- `<mod_workshop_item_id>`: the Steam Workshop item ID of each mod.
- `<last_write_timestamp>`: `LastWriteTime` property of each mod.


## TODO

- [] Use `Compress-Archive` to create archive on host does NOT have 7-Zip installed.
- [] Use config to memorize some parameters used last time to boost process and simplify parameters provided by user.