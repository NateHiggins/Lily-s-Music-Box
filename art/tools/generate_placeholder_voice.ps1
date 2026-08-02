# Placeholder voice takes from the dialogue JSON, via Windows' offline
# synthesizer. These are TEMP VO in the production sense: they prove the
# whole chain (tree -> take -> import -> in-game playback + subtitles) and
# hold the timing until real performances land. Replacing them is dropping
# better files with the same names into voice/source/ and re-running
# import_voice_takes.py - nothing else changes.
#
#   powershell art/tools/generate_placeholder_voice.ps1 `
#       -Json game/data/case01_dialogue.json -Prefix mina_c01_ -Voice Zira
param(
    [string]$Json = "game/data/case01_dialogue.json",
    [string]$Prefix = "mina_c01_",
    [string]$Voice = "Zira",
    [int]$Rate = -1     # slightly slow: Mina is exacting, not hurried
)
Add-Type -AssemblyName System.Speech
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$picked = $synth.GetInstalledVoices() |
    Where-Object { $_.VoiceInfo.Name -like "*$Voice*" } |
    Select-Object -First 1
if ($picked) { $synth.SelectVoice($picked.VoiceInfo.Name) }
$synth.Rate = $Rate
$root = Split-Path (Split-Path $PSScriptRoot)
$out = Join-Path $root "game/assets/audio/voice/source"
New-Item -ItemType Directory -Force $out | Out-Null
$data = Get-Content (Join-Path $root $Json) -Raw | ConvertFrom-Json
$made = 0
foreach ($prop in $data.nodes.PSObject.Properties) {
    $line = $prop.Value.line
    if (-not $line) { continue }
    $file = Join-Path $out ($Prefix + $prop.Name + ".wav")
    $synth.SetOutputToWaveFile($file)
    $synth.Speak($line)
    $synth.SetOutputToNull()
    $made++
}
$synth.Dispose()
Write-Output "$made placeholder takes -> $out (voice: $($picked.VoiceInfo.Name))"
