Write-Host "1. Executing build scripts."

.\eng\scripts\New-BuildInfo.ps1 -ServerName 'Azure.Mcp.Server'
.\eng\scripts\Build-Code.ps1 -ServerName Azure.Mcp.Server -ReleaseBuild -PlatformName "windows-x64"

Write-Host "2. Executing OOM script."

.\.work\Run-VallyOom.ps1