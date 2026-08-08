# Shattered — manual APK build (no Gradle), mirrors the Velvet Maze recipe:
# aapt2 compile/link -> javac -> d8 -> jar uf classes.dex -> zipalign -> apksigner
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$sdk  = "$env:LOCALAPPDATA\Android\Sdk"
$bt   = "$sdk\build-tools\34.0.0"
$jar  = "$sdk\platforms\android-34\android.jar"
$jdk  = 'C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot'
$ks   = "$env:USERPROFILE\.android\shattered.keystore"

Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force build\gen, build\classes | Out-Null

# Fresh copy of the game into assets so the APK never ships a stale build
Copy-Item ..\index.html assets\index.html -Force

& "$bt\aapt2.exe" compile --dir res -o build\res.zip
& "$bt\aapt2.exe" link -o build\base.apk -I $jar --manifest AndroidManifest.xml `
    -A assets --java build\gen --min-sdk-version 24 --target-sdk-version 34 `
    --auto-add-overlay build\res.zip

& "$jdk\bin\javac.exe" -nowarn -classpath $jar -d build\classes `
    build\gen\com\gildedmoth\shattered\R.java `
    java\com\gildedmoth\shattered\MainActivity.java

$classes = Get-ChildItem build\classes -Recurse -Filter *.class | ForEach-Object { $_.FullName }
& "$bt\d8.bat" --release --lib $jar --output build @classes

Push-Location build
& "$jdk\bin\jar.exe" uf base.apk classes.dex
Pop-Location

& "$bt\zipalign.exe" -f 4 build\base.apk build\aligned.apk

if (-not (Test-Path $ks)) {
    # New keystore, NOT Velvet Maze's — separate app identity on purpose
    & "$jdk\bin\keytool.exe" -genkeypair -keystore $ks -alias shattered `
        -storepass shattered -keypass shattered -keyalg RSA -keysize 2048 `
        -validity 10950 -dname "CN=Gilded Moth Productions, OU=Shattered"
    Write-Host "Created NEW keystore: $ks"
}

& "$bt\apksigner.bat" sign --ks $ks --ks-key-alias shattered --ks-pass pass:shattered `
    --key-pass pass:shattered --out ..\Shattered.apk build\aligned.apk

& "$bt\apksigner.bat" verify ..\Shattered.apk
Write-Host "Built and signed: D:\Python projects\Shattered\Shattered.apk"
