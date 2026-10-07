param(
    [string]$OutputDir
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
if (-not $OutputDir) {
    $OutputDir = Join-Path $Root "publish\win-x64\DAP-Port-26.3"
}
$Work = Join-Path $env:RUNNER_TEMP "dap-port-26.3"
$Source = Join-Path $Work "Dap-ur-homie"
$MigrationLog = Join-Path $OutputDir "migrate.log"
$BuildLog = Join-Path $OutputDir "build.log"
$StatusFile = Join-Path $OutputDir "BUILD_STATUS.txt"

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

function Write-Status([string]$Text) {
    Set-Content -Path $StatusFile -Value $Text -Encoding UTF8
    Write-Host $Text -ForegroundColor Cyan
}

function Use-JavaVersion([int]$Version) {
    $envName = "JAVA_HOME_$Version" + "_X64"
    $home = [Environment]::GetEnvironmentVariable($envName)

    if (-not $home -or -not (Test-Path (Join-Path $home "bin\java.exe"))) {
        Write-Host "Java $Version not preinstalled; installing Temurin..." -ForegroundColor Yellow
        choco install "temurin$Version" --no-progress -y
        if ($LASTEXITCODE -ne 0) {
            throw "Chocolatey failed to install Temurin $Version."
        }

        $base = "C:\Program Files\Eclipse Adoptium"
        $candidate = Get-ChildItem $base -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "jdk-$Version*" } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if (-not $candidate) {
            throw "Could not locate JDK $Version."
        }
        $home = $candidate.FullName
    }

    $env:JAVA_HOME = $home
    $filtered = $env:Path -split ';' | Where-Object { $_ -and $_ -notmatch '\\Java\\|\\jdk-' }
    $env:Path = "$home\bin;" + ($filtered -join ';')
    Write-Host "Using JAVA_HOME=$home" -ForegroundColor Cyan
    & java -version
    if ($LASTEXITCODE -ne 0) {
        throw "Java $Version failed to start."
    }
}

try {
    Write-Status "STARTED"

    if (Test-Path $Work) {
        Remove-Item $Work -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Work | Out-Null

    Write-Host "Cloning DAP ur Homies 1.21.11..." -ForegroundColor Cyan
    git clone --depth 1 --branch 1.21.11 https://github.com/itsfirecat/Dap-ur-homie.git $Source 2>&1 |
        Tee-Object -FilePath $MigrationLog
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone DAP source."
    }

    Push-Location $Source
    try {
        Use-JavaVersion 21

        Write-Host "Migrating Yarn to Mojang mappings on Minecraft 1.21.11..." -ForegroundColor Cyan
        & .\gradlew.bat migrateMappings --mappings "net.minecraft:mappings:1.21.11" --overrideInputsIHaveABackup --no-daemon --stacktrace 2>&1 |
            Tee-Object -FilePath $MigrationLog -Append
        if ($LASTEXITCODE -ne 0) {
            throw "migrateMappings failed."
        }

        Write-Host "Patching project to Minecraft 26.3..." -ForegroundColor Cyan

        $propsPath = Join-Path $Source "gradle.properties"
        $props = Get-Content $propsPath -Raw
        $props = [regex]::Replace($props, '(?m)^minecraft_version=.*$', 'minecraft_version=26.3')
        $props = [regex]::Replace($props, '(?m)^loader_version=.*$', 'loader_version=0.19.5')
        $props = [regex]::Replace($props, '(?m)^loom_version=.*$', 'loom_version=1.17')
        $props = [regex]::Replace($props, '(?m)^fabric_api_version=.*$', 'fabric_api_version=0.161.0+26.3')
        $props = [regex]::Replace($props, '(?m)^mod_version=.*$', 'mod_version=3.0.0+mc-26.3-port.1')
        $props = [regex]::Replace($props, '(?m)^pal_version\s*=.*$', 'pal_version=1.2.7+mc.26.3')
        $props = [regex]::Replace($props, '(?m)^yarn_mappings=.*\r?\n?', '')
        Set-Content $propsPath $props -NoNewline

        $gradlePath = Join-Path $Source "build.gradle"
        $gradle = Get-Content $gradlePath -Raw
        $gradle = $gradle.Replace("id 'net.fabricmc.fabric-loom-remap'", "id 'net.fabricmc.fabric-loom'")
        $gradle = [regex]::Replace($gradle, '(?m)^\s*mappings\s+.*\r?\n', '')
        $gradle = $gradle.Replace('modImplementation "net.fabricmc:fabric-loader:${project.loader_version}"', 'implementation "net.fabricmc:fabric-loader:${project.loader_version}"')
        $gradle = $gradle.Replace('modImplementation "net.fabricmc.fabric-api:fabric-api:${project.fabric_api_version}"', 'implementation "net.fabricmc.fabric-api:fabric-api:${project.fabric_api_version}"')
        $gradle = $gradle.Replace('modImplementation "com.zigythebird.playeranim:PlayerAnimationLibFabric:$pal_version"', 'implementation "maven.modrinth:ha1mEyJS:kemJXVHZ"')

        $oldRepos = @'
repositories {
    mavenCentral()
    maven {
        url = "https://maven.fabricmc.net/"
    }
    maven {
        name = "RedlanceMinecraft"
        url = "https://repo.redlance.org/public"
    }
}
'@
        $newRepos = @'
repositories {
    mavenCentral()
    maven {
        url = "https://maven.fabricmc.net/"
    }
    maven {
        name = "Modrinth"
        url = "https://api.modrinth.com/maven"
        content {
            includeGroup "maven.modrinth"
        }
    }
    maven {
        name = "RedlanceMinecraft"
        url = "https://repo.redlance.org/public"
    }
}
'@
        if ($gradle.Contains($oldRepos)) {
            $gradle = $gradle.Replace($oldRepos, $newRepos)
        } elseif ($gradle -notmatch 'api\.modrinth\.com/maven') {
            throw "Could not patch repositories block safely."
        }

        $gradle = $gradle.Replace('options.release = 21', 'options.release = 25')
        $gradle = $gradle.Replace('JavaVersion.VERSION_21', 'JavaVersion.VERSION_25')
        $gradle = [regex]::Replace(
            $gradle,
            'artifact\(remapJar\)\s*\{\s*builtBy\s+remapJar\s*\}',
            'artifact(jar) { builtBy jar }'
        )
        Set-Content $gradlePath $gradle -NoNewline

        $wrapperPath = Join-Path $Source "gradle\wrapper\gradle-wrapper.properties"
        $wrapper = Get-Content $wrapperPath -Raw
        $wrapper = [regex]::Replace($wrapper, 'gradle-[0-9.]+-bin\.zip', 'gradle-9.6.0-bin.zip')
        Set-Content $wrapperPath $wrapper -NoNewline

        $fabricPath = Join-Path $Source "src\main\resources\fabric.mod.json"
        $fabric = Get-Content $fabricPath -Raw | ConvertFrom-Json
        $fabric.version = '${version}'
        $fabric.depends.fabricloader = '>=0.19.5'
        $fabric.depends.minecraft = '~26.3'
        $fabric.depends.java = '>=25'
        $fabric.depends.'fabric-api' = '>=0.161.0'
        $fabric.depends.player_animation_library = '>=1.2.7'
        $fabric | ConvertTo-Json -Depth 20 | Set-Content $fabricPath

        $mixinPath = Join-Path $Source "src\main\resources\testcoop.mixins.json"
        $mixin = Get-Content $mixinPath -Raw | ConvertFrom-Json
        $mixin.compatibilityLevel = 'JAVA_25'
        $mixin | ConvertTo-Json -Depth 20 | Set-Content $mixinPath

        $awPath = Join-Path $Source "src\main\resources\testcoop.accesswidener"
        $aw = Get-Content $awPath -Raw
        $aw = $aw.Replace('accessWidener v2 named', 'accessWidener v2 official')
        $aw = $aw.Replace('net/minecraft/entity/Entity', 'net/minecraft/world/entity/Entity')
        Set-Content $awPath $aw -NoNewline

        $renames = [ordered]@{
            'net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper' = 'net.fabricmc.fabric.api.client.keymapping.v1.KeyMappingHelper'
            'KeyBindingHelper' = 'KeyMappingHelper'
            'registerKeyBinding' = 'registerKeyMapping'
            'ClientCommandManager' = 'ClientCommands'
            'WorldRenderEvents' = 'LevelRenderEvents'
        }
        Get-ChildItem (Join-Path $Source "src\main\java") -Recurse -Filter *.java | ForEach-Object {
            $text = Get-Content $_.FullName -Raw
            foreach ($entry in $renames.GetEnumerator()) {
                $text = $text.Replace($entry.Key, $entry.Value)
            }
            Set-Content $_.FullName $text -NoNewline
        }

        Use-JavaVersion 25

        Write-Host "Building Minecraft 26.3 candidate..." -ForegroundColor Cyan
        & .\gradlew.bat clean build --no-daemon --stacktrace --warning-mode all 2>&1 |
            Tee-Object -FilePath $BuildLog
        $buildExit = $LASTEXITCODE

        $snapshot = Join-Path $OutputDir "migrated-source"
        if (Test-Path $snapshot) {
            Remove-Item $snapshot -Recurse -Force
        }
        New-Item -ItemType Directory -Path $snapshot | Out-Null
        Copy-Item (Join-Path $Source "build.gradle") $snapshot
        Copy-Item (Join-Path $Source "gradle.properties") $snapshot
        Copy-Item (Join-Path $Source "src\main\java") $snapshot -Recurse
        New-Item -ItemType Directory -Path (Join-Path $snapshot "resources") | Out-Null
        Copy-Item $fabricPath (Join-Path $snapshot "resources")
        Copy-Item $mixinPath (Join-Path $snapshot "resources")
        Copy-Item $awPath (Join-Path $snapshot "resources")

        if ($buildExit -ne 0) {
            Write-Status "BUILD_FAILED"
            Write-Host "DAP 26.3 build failed; diagnostics preserved." -ForegroundColor Red
            return
        }

        $artifactDir = Join-Path $OutputDir "jars"
        New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
        Get-ChildItem (Join-Path $Source "build\libs") -Filter *.jar |
            Copy-Item -Destination $artifactDir

        Write-Status "BUILD_SUCCEEDED"
        Write-Host "DAP 26.3 build succeeded." -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
}
catch {
    $_ | Out-String | Set-Content (Join-Path $OutputDir "exception.txt") -Encoding UTF8
    Write-Status "PORT_SCRIPT_FAILED"
    Write-Host $_ -ForegroundColor Red
}
