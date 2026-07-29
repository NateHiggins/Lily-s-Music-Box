# One-command backup: commit all local work and push it to GitHub.
# Usage (from the repo root, in PowerShell):
#   .\tools\backup.ps1
#   .\tools\backup.ps1 "finished tuning the corridor lights"
param([string]$Message = "")

if ($Message -eq "") {
    $Message = "backup: work in progress " + (Get-Date -Format "yyyy-MM-dd HH:mm")
}

git add -A
git commit -m $Message
if ($LASTEXITCODE -ne 0) {
    Write-Host "Nothing new to back up." -ForegroundColor Yellow
}
git push
if ($LASTEXITCODE -eq 0) {
    Write-Host "Backed up to GitHub." -ForegroundColor Green
} else {
    Write-Host "Push failed - check your network/login and run .\tools\backup.ps1 again." -ForegroundColor Red
}
