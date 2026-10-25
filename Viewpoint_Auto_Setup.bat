@echo off
title Project Viewpoint Ultimate Setup - Auto-Installer
color 0A
echo ============================================================================
echo    PROJECT VIEWPOINT ULTIMATE OVERHAUL - ONE-CLICK AUTO-INSTALLER (B42.21)
echo ============================================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$ErrorActionPreference = 'Continue'; ^
Write-Host '[1/6] Locating Steam and Project Zomboid across all drives...' -ForegroundColor Cyan; ^
$steamPath = (Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath; ^
if (-not $steamPath) { $steamPath = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -ErrorAction SilentlyContinue).InstallPath }; ^
if (-not $steamPath) { $steamPath = 'C:\Program Files (x86)\Steam' }; ^
$steamPath = $steamPath -replace '/', '\'; ^
$libPaths = @($steamPath, 'C:\Steam', 'D:\Steam', 'D:\SteamLibrary', 'E:\Steam', 'E:\SteamLibrary', 'F:\SteamLibrary', 'G:\SteamLibrary'); ^
$vdf = Join-Path $steamPath 'steamapps\libraryfolders.vdf'; ^
if (Test-Path $vdf) { ^
    $matches = [regex]::Matches((Get-Content $vdf -Raw), '\"path\"\s+\"([^\"]+)\"'); ^
    foreach ($m in $matches) { $libPaths += ($m.Groups[1].Value -replace '\\\\', '\') } ^
}; ^
$pzDir = $null; $workshopDir = $null; ^
foreach ($lp in ($libPaths | Select-Object -Unique)) { ^
    if ($lp -and (Test-Path $lp)) { ^
        $testPz = Join-Path $lp 'steamapps\common\ProjectZomboid'; ^
        if (Test-Path $testPz) { $pzDir = $testPz }; ^
        $testWs = Join-Path $lp 'steamapps\workshop\content\108600'; ^
        if (Test-Path (Join-Path $testWs '3809306528')) { $workshopDir = $testWs } elseif ((-not $workshopDir) -and (Test-Path $testWs)) { $workshopDir = $testWs }; ^
    } ^
}; ^
if (-not $pzDir) { Write-Host 'ERROR: Project Zomboid installation not found!' -ForegroundColor Red; exit 1 }; ^
Write-Host ('  -> Found Project Zomboid: ' + $pzDir) -ForegroundColor Green; ^
if ($workshopDir) { Write-Host ('  -> Found Workshop folder: ' + $workshopDir) -ForegroundColor Green }; ^
 ^
Write-Host '[2/6] Installing ZombieBuddy & Configuring 8 GB RAM + Launch Args...' -ForegroundColor Cyan; ^
if ($workshopDir) { ^
    $zbLibs = Join-Path $workshopDir '3619862853\mods\ZombieBuddy\libs'; ^
    if (Test-Path $zbLibs) { ^
        Copy-Item (Join-Path $zbLibs 'ZombieBuddy.jar') -Destination $pzDir -Force -ErrorAction SilentlyContinue; ^
        Copy-Item (Join-Path $zbLibs 'zbNative.dll') -Destination $pzDir -Force -ErrorAction SilentlyContinue; ^
        Write-Host '  -> Copied ZombieBuddy.jar and zbNative.dll to game folder.' -ForegroundColor Green; ^
    } else { Write-Host '  -> WARNING: ZombieBuddy (3619862853) not yet downloaded by Steam. Make sure to Subscribe to All first!' -ForegroundColor Yellow } ^
}; ^
$jsonPath = Join-Path $pzDir 'ProjectZomboid64.json'; ^
if (Test-Path $jsonPath) { ^
    $json = Get-Content $jsonPath -Raw; ^
    $json = $json -replace '-Xmx\d+m', '-Xmx8192m'; ^
    if ($json -notmatch '-agentlib:zbNative') { ^
        $json = $json -replace '\"vmArgs\"\s*:\s*\[', '\"vmArgs\" : [ \"-agentlib:zbNative\", '; ^
    }; ^
    Set-Content -Path $jsonPath -Value $json -NoNewline; ^
    Write-Host '  -> Updated ProjectZomboid64.json (-Xmx8192m & -agentlib:zbNative).' -ForegroundColor Green; ^
}; ^
$batPath = Join-Path $pzDir 'ProjectZomboid64.bat'; ^
if (Test-Path $batPath) { ^
    $bat = Get-Content $batPath -Raw; ^
    $bat = $bat -replace '-Xmx\d+m', '-Xmx8192m'; ^
    Set-Content -Path $batPath -Value $bat -NoNewline; ^
}; ^
 ^
Write-Host '[3/6] Installing Shader Packs (Bliss, Photon, Complementary, Redraw, Deadwood, Hollow Light)...' -ForegroundColor Cyan; ^
$zomboidUser = Join-Path $env:USERPROFILE 'Zomboid'; ^
$shaderDir = Join-Path $zomboidUser 'viewpoint-shaderpacks'; ^
New-Item -ItemType Directory -Force -Path $shaderDir | Out-Null; ^
if ($workshopDir) { ^
    $wsShaders = @( ^
        (Join-Path $workshopDir '3818548144\mods\Redraw\shaderpacks'), ^
        (Join-Path $workshopDir '3818656834\mods\Deadwood-Shaders\common\shaderpacks'), ^
        (Join-Path $workshopDir '3821721515\mods\HollowLightShaders\common\shaderpacks') ^
    ); ^
    foreach ($ws in $wsShaders) { ^
        if (Test-Path $ws) { ^
            Get-ChildItem $ws -Directory | ForEach-Object { ^
                Copy-Item $_.FullName -Destination (Join-Path $shaderDir $_.Name) -Recurse -Force; ^
                Write-Host ('  -> Installed Workshop Shader: ' + $_.Name) -ForegroundColor Green; ^
            } ^
        } ^
    } ^
}; ^
$modrinthShaders = @('bliss-shader', 'photon-shader', 'complementary-unbound'); ^
foreach ($ms in $modrinthShaders) { ^
    try { ^
        $v = (Invoke-RestMethod -Uri ('https://api.modrinth.com/v2/project/' + $ms + '/version'))[0].files[0]; ^
        $out = Join-Path $shaderDir $v.filename; ^
        if (-not (Test-Path $out)) { ^
            Invoke-WebRequest -Uri $v.url -OutFile $out; ^
            Write-Host ('  -> Downloaded Modrinth Shader: ' + $v.filename) -ForegroundColor Green; ^
        } else { Write-Host ('  -> Shader already present: ' + $v.filename) -ForegroundColor DarkGray } ^
    } catch { Write-Host ('  -> Skipped shader ' + $ms) -ForegroundColor Yellow } ^
}; ^
 ^
Write-Host '[4/6] Installing yt-dlp & FFmpeg for 3D Working TVs (YouTube)...' -ForegroundColor Cyan; ^
if (Get-Command winget -ErrorAction SilentlyContinue) { ^
    if (-not (Get-Command yt-dlp -ErrorAction SilentlyContinue)) { ^
        winget install --id yt-dlp.yt-dlp -e --accept-source-agreements --accept-package-agreements --silent; ^
    }; ^
    if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) { ^
        winget install --id Gyan.FFmpeg -e --accept-source-agreements --accept-package-agreements --silent; ^
    }; ^
    Write-Host '  -> yt-dlp and FFmpeg verified/installed.' -ForegroundColor Green; ^
}; ^
 ^
Write-Host '[5/6] Writing Optimal Mod Load Order (default.txt)...' -ForegroundColor Cyan; ^
$modsDir = Join-Path $zomboidUser 'mods'; ^
New-Item -ItemType Directory -Force -Path $modsDir | Out-Null; ^
$defaultTxt = @'
VERSION = 1,

mods
{
	mod = \ZombieBuddy,
	mod = \ChuckleberryFinnAlertSystem,
	mod = \errorMagnifier,
	mod = \SWMG,
	mod = \Viewpoint,
	mod = \DGVViewpointDoctor,
	mod = \PZVoxelStudioViewpoint,
	mod = \ViewpointProperRoofs,
	mod = \BasileDoors3D,
	mod = \DGVWindows3D,
	mod = \DGVCurtains,
	mod = \ViewpointShelves3D,
	mod = \ViewpointLivingProps,
	mod = \ViewpointRocks3D,
	mod = \ViewpointPhysicsProps,
	mod = \KnoxRealTerrain,
	mod = \ViewpointBetterTerrain,
	mod = \ViewPointTreePack,
	mod = \ViewpointFarTreeModels,
	mod = \ProjectViewpointNearVegetation,
	mod = \GrassierGrassViewpoint,
	mod = \GrassierPixels,
	mod = \GrassierGrassViewDistance,
	mod = \ViewpointWindSway,
	mod = \TrueSwimming,
	mod = \TrueWater,
	mod = \fhqMotoriousZone,
	mod = \fhqMotoriousZoneRealNames,
	mod = \MZInteriors,
	mod = \MZInteriorsGlass,
	mod = \ViewpointInteriors,
	mod = \ImmersiveDriving,
	mod = \LabVehiclePhysics,
	mod = \VehicleSafety,
	mod = \ViewpointImmersiveWeathers,
	mod = \LiveWristwatch,
	mod = \ViewpointWorkingTVs,
	mod = \YTBoombox,
	mod = \EscapeFromZomboidFirearms,
	mod = \ProjectViewpointQOL,
	mod = \ViewpointUI,
	mod = \ViewpointUIPlus,
	mod = \SkillRecoveryJournal,
}

maps
{
}
'@; ^
Set-Content -Path (Join-Path $modsDir 'default.txt') -Value $defaultTxt; ^
Write-Host '  -> Wrote C:\Users\...\Zomboid\mods\default.txt' -ForegroundColor Green; ^
 ^
Write-Host '[6/6] Optimizing Viewpoint Memory Pools (viewpoint-live.properties)...' -ForegroundColor Cyan; ^
$vpProps = Join-Path $zomboidUser 'viewpoint-live.properties'; ^
if (Test-Path $vpProps) { ^
    $vp = Get-Content $vpProps -Raw; ^
    $vp = $vp -replace 'memory\.packMiB=\d+', 'memory.packMiB=2560'; ^
    $vp = $vp -replace 'memory\.modelMeshMiB=\d+', 'memory.modelMeshMiB=1536'; ^
    $vp = $vp -replace 'memory\.nearMeshMiB=\d+', 'memory.nearMeshMiB=1024'; ^
    Set-Content -Path $vpProps -Value $vp -NoNewline; ^
    Write-Host '  -> Updated viewpoint-live.properties memory pools.' -ForegroundColor Green; ^
} else { ^
    $newVp = \"memory.packMiB=2560`r`nmemory.modelMeshMiB=1536`r`nmemory.nearMeshMiB=1024`r`n\"; ^
    Set-Content -Path $vpProps -Value $newVp -NoNewline; ^
    Write-Host '  -> Created viewpoint-live.properties with optimized memory pools.' -ForegroundColor Green; ^
}; ^
Write-Host ''; ^
Write-Host '============================================================================' -ForegroundColor Green; ^
Write-Host '  SETUP COMPLETE! Launch Project Zomboid via Steam and click ALLOW on the' -ForegroundColor Green; ^
Write-Host '  ZombieBuddy prompts in the main menu, then restart the game once!' -ForegroundColor Green; ^
Write-Host '============================================================================' -ForegroundColor Green;"

echo.
pause
