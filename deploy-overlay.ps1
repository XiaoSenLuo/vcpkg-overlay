# Deploy this overlay repository into a vcpkg installation:
#   ports/      -> <vcpkg-root>/overlay/ports
#   toolchains/ -> <vcpkg-root>/scripts/toolchains
#   triplets/   -> <vcpkg-root>/triplets
# Existing files with the same name are renamed to <file-name>.origin;
# --restore deletes the deployed files and renames the *.origin ones back.
#
# Usage: powershell -ExecutionPolicy Bypass -File deploy-overlay.ps1 --vcpkg-root <path> [--restore]

$ErrorActionPreference = "Stop"

function Usage {
    Write-Host "Usage: powershell -ExecutionPolicy Bypass -File deploy-overlay.ps1 --vcpkg-root <path> [--restore]"
    Write-Host "  --vcpkg-root <path>  vcpkg installation root directory (required)"
    Write-Host "  --restore            remove deployed files and restore *.origin backups"
}

$VcpkgRoot = ""
$Restore = $false
for ($i = 0; $i -lt $args.Count; $i++) {
    $opt = [string]$args[$i]
    if ($opt -eq "--vcpkg-root") {
        if ($i + 1 -ge $args.Count) { Write-Host "error: --vcpkg-root requires a value"; exit 2 }
        $VcpkgRoot = [string]$args[$i + 1]
        $i++
    } elseif ($opt.StartsWith("--vcpkg-root=")) {
        $VcpkgRoot = $opt.Substring("--vcpkg-root=".Length)
    } elseif ($opt -eq "--restore") {
        $Restore = $true
    } elseif ($opt -eq "-h" -or $opt -eq "--help") {
        Usage
        exit 0
    } else {
        Write-Host "error: unknown option: $opt"
        Usage
        exit 2
    }
}

if (-not $VcpkgRoot) {
    Write-Host "error: --vcpkg-root is not specified."
    Write-Host "Please install vcpkg first (https://github.com/microsoft/vcpkg),"
    Write-Host "then pass its root directory with --vcpkg-root <path>."
    exit 1
}

try {
    $VcpkgRoot = (Resolve-Path -LiteralPath $VcpkgRoot).Path
} catch {
    Write-Host "error: vcpkg root not found: $VcpkgRoot"
    exit 1
}
if (-not (Test-Path -LiteralPath (Join-Path $VcpkgRoot "scripts/toolchains"))) {
    Write-Host "error: '$VcpkgRoot' is not a vcpkg root (scripts/toolchains not found)."
    exit 1
}

$script:CopiedCount = 0
$script:ReservedCount = 0
$script:RemovedCount = 0
$script:RestoredCount = 0

# rename an existing destination entry to <name>.origin
function Reserve-File([string]$Target) {
    if (Test-Path -LiteralPath "$Target.origin") {
        Write-Host "note: '$Target.origin' already exists, keeping it"
    } else {
        Move-Item -LiteralPath $Target -Destination "$Target.origin"
        Write-Host "reserved: $Target -> $Target.origin"
        $script:ReservedCount++
    }
}

function Deploy-Tree([string]$Src, [string]$Dst) {
    New-Item -ItemType Directory -Force -Path $Dst | Out-Null
    foreach ($entry in @(Get-ChildItem -LiteralPath $Src -Force)) {
        $target = Join-Path $Dst $entry.Name
        if ($entry.PSIsContainer) {
            if ((Test-Path -LiteralPath $target) -and -not (Get-Item -LiteralPath $target -Force).PSIsContainer) {
                Reserve-File $target
            }
            Deploy-Tree $entry.FullName $target
        } else {
            if (Test-Path -LiteralPath $target) { Reserve-File $target }
            Copy-Item -LiteralPath $entry.FullName -Destination $target -Force
            Write-Host "copied: $($entry.FullName) -> $target"
            $script:CopiedCount++
        }
    }
}

function Restore-Tree([string]$Src, [string]$Dst) {
    if (-not (Test-Path -LiteralPath $Dst)) { return }
    foreach ($entry in @(Get-ChildItem -LiteralPath $Src -Force)) {
        $target = Join-Path $Dst $entry.Name
        if ($entry.PSIsContainer) {
            Restore-Tree $entry.FullName $target
        } else {
            if (Test-Path -LiteralPath $target) {
                Remove-Item -LiteralPath $target -Force -Recurse
                Write-Host "removed: $target"
                $script:RemovedCount++
            }
            if (Test-Path -LiteralPath "$target.origin") {
                Move-Item -LiteralPath "$target.origin" -Destination $target
                Write-Host "restored: $target.origin -> $target"
                $script:RestoredCount++
            }
        }
    }
}

# remove empty sub-directories of $Root (deepest first), keeping $Root itself
function Remove-EmptyDirs([string]$Root) {
    if (-not (Test-Path -LiteralPath $Root)) { return }
    Get-ChildItem -LiteralPath $Root -Directory -Recurse -Force |
        Sort-Object { $_.FullName.Length } -Descending |
        ForEach-Object {
            if (-not @(Get-ChildItem -LiteralPath $_.FullName -Force)) {
                Write-Host "removed empty dir: $($_.FullName)"
                Remove-Item -LiteralPath $_.FullName
            }
        }
}

# remove $Path only if it is an empty directory
function Remove-DirIfEmpty([string]$Path) {
    if ((Test-Path -LiteralPath $Path) -and -not @(Get-ChildItem -LiteralPath $Path -Force)) {
        Write-Host "removed empty dir: $Path"
        Remove-Item -LiteralPath $Path
    }
}

$DstPorts = Join-Path (Join-Path $VcpkgRoot "overlay") "ports"
$DstToolchains = Join-Path (Join-Path $VcpkgRoot "scripts") "toolchains"
$DstTriplets = Join-Path $VcpkgRoot "triplets"

if ($Restore) {
    Restore-Tree (Join-Path $PSScriptRoot "ports") $DstPorts
    Restore-Tree (Join-Path $PSScriptRoot "toolchains") $DstToolchains
    Restore-Tree (Join-Path $PSScriptRoot "triplets") $DstTriplets
    Remove-EmptyDirs $DstPorts
    Remove-DirIfEmpty $DstPorts
    Remove-DirIfEmpty (Join-Path $VcpkgRoot "overlay")
    Remove-EmptyDirs $DstToolchains
    Remove-EmptyDirs $DstTriplets
    Write-Host "restore finished: removed $RemovedCount file(s), restored $RestoredCount backup(s)"
} else {
    $stale = Get-ChildItem -Path $DstPorts, $DstToolchains, $DstTriplets -Recurse -Filter "*.origin" -Force -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($stale) {
        Write-Host "error: found '$($stale.FullName)' left by a previous deploy."
        Write-Host "Run with --vcpkg-root <path> --restore first, then deploy again."
        exit 1
    }
    Deploy-Tree (Join-Path $PSScriptRoot "ports") $DstPorts
    Deploy-Tree (Join-Path $PSScriptRoot "toolchains") $DstToolchains
    Deploy-Tree (Join-Path $PSScriptRoot "triplets") $DstTriplets
    Write-Host "deploy finished: copied $CopiedCount file(s), reserved $ReservedCount original(s) as *.origin"
}
