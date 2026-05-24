$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$root = "X:\Jarvis"
$ollamaRoot = "$root\Ollama"
$ollamaApp = "$ollamaRoot\app"
$ollamaModels = "$ollamaRoot\models"
$ollamaLogs = "$ollamaRoot\logs"
$temp = "$root\temp"
$jarvisHome = "$root\home"
$localAppData = "$root\localappdata"
$programData = "$root\programdata"
$scripts = "$root\scripts"
$tools = "$root\tools"
$tts = "$root\tts-service"
$ttsCache = "$tts\cache"

$requiredDirs = @(
  $root,
  $ollamaRoot,
  $ollamaApp,
  $ollamaModels,
  $ollamaLogs,
  $temp,
  $jarvisHome,
  $localAppData,
  $programData,
  $scripts,
  $tools,
  $tts,
  "$tts\logs",
  $ttsCache,
  "$ttsCache\uv",
  "$ttsCache\pip",
  "$ttsCache\huggingface",
  "$ttsCache\torch",
  "$ttsCache\transformers",
  "$ttsCache\matplotlib",
  "$ttsCache\numba",
  "$root\python",
  "$root\voices\chatterbox\references"
)
New-Item -ItemType Directory -Force -Path $requiredDirs | Out-Null

$installedOllama = Join-Path $env:LOCALAPPDATA "Programs\Ollama"
if (-not (Test-Path "$installedOllama\ollama.exe")) {
  throw "Installed Ollama was not found at $installedOllama"
}
Copy-Item "$installedOllama\*" $ollamaApp -Recurse -Force

$lhmDll = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter LibreHardwareMonitorLib.dll -ErrorAction SilentlyContinue |
  Select-Object -First 1 -ExpandProperty FullName
if ($lhmDll) {
  $lhmSource = Split-Path $lhmDll
  $lhmDest = "$tools\LibreHardwareMonitor"
  New-Item -ItemType Directory -Force -Path $lhmDest | Out-Null
  Copy-Item "$lhmSource\*" $lhmDest -Recurse -Force
}

$commonRuntime = @'
$ErrorActionPreference = "Stop"
$root = "X:\Jarvis"
$env:JARVIS_ROOT = $root
$env:HOME = "$root\home"
$env:USERPROFILE = "$root\home"
$env:LOCALAPPDATA = "$root\localappdata"
$env:APPDATA = "$root\appdata"
$env:PROGRAMDATA = "$root\programdata"
$env:TEMP = "$root\temp"
$env:TMP = "$root\temp"
$env:OLLAMA_HOST = "0.0.0.0:11434"
$env:OLLAMA_ORIGINS = "*"
$env:OLLAMA_MODELS = "$root\Ollama\models"
$env:OLLAMA_KEEP_ALIVE = "12h"
$env:OLLAMA_VULKAN = "true"
$env:OLLAMA_NEW_ENGINE = "true"
$env:OLLAMA_LLM_LIBRARY = "vulkan"
$env:OLLAMA_NUM_PARALLEL = "1"
New-Item -ItemType Directory -Force -Path `
  "$root\home", `
  "$root\localappdata", `
  "$root\appdata", `
  "$root\programdata", `
  "$root\temp", `
  "$root\Ollama\models", `
  "$root\Ollama\logs" | Out-Null
'@

@"
$commonRuntime
`$exe = "X:\Jarvis\Ollama\app\ollama.exe"
`$out = "X:\Jarvis\Ollama\logs\gpu-server.out.log"
`$err = "X:\Jarvis\Ollama\logs\gpu-server.err.log"
if (-not (Test-Path `$exe)) { throw "Missing Ollama executable at `$exe" }
Start-Process -FilePath `$exe -ArgumentList "serve" -WorkingDirectory "X:\Jarvis\Ollama\app" -WindowStyle Hidden -RedirectStandardOutput `$out -RedirectStandardError `$err
"@ | Set-Content -Path "$scripts\start-ollama-gpu-hidden.ps1" -Encoding UTF8

@'
@echo off
set "JARVIS_ROOT=X:\Jarvis"
set "HOME=X:\Jarvis\home"
set "USERPROFILE=X:\Jarvis\home"
set "LOCALAPPDATA=X:\Jarvis\localappdata"
set "APPDATA=X:\Jarvis\appdata"
set "PROGRAMDATA=X:\Jarvis\programdata"
set "TEMP=X:\Jarvis\temp"
set "TMP=X:\Jarvis\temp"
set "OLLAMA_HOST=0.0.0.0:11434"
set "OLLAMA_ORIGINS=*"
set "OLLAMA_MODELS=X:\Jarvis\Ollama\models"
set "OLLAMA_KEEP_ALIVE=12h"
set "OLLAMA_VULKAN=true"
set "OLLAMA_NEW_ENGINE=true"
set "OLLAMA_LLM_LIBRARY=vulkan"
set "OLLAMA_NUM_PARALLEL=1"
"X:\Jarvis\Ollama\app\ollama.exe" serve >> "X:\Jarvis\Ollama\logs\gpu-server.log" 2>&1
'@ | Set-Content -Path "$scripts\start-ollama-gpu.cmd" -Encoding ASCII

@'
$ErrorActionPreference = "SilentlyContinue"
$root = "X:\Jarvis"
$env:TEMP = "$root\temp"
$env:TMP = "$root\temp"
$listener = Get-NetTCPConnection -LocalPort 11434 -State Listen -ErrorAction SilentlyContinue
if (-not $listener) {
  Start-ScheduledTask -TaskName "Ollama GPU Server"
}
'@ | Set-Content -Path "$scripts\watch-ollama-gpu.ps1" -Encoding UTF8

@"
$commonRuntime
`$body = @{
  model = "qwen3:14b"
  prompt = "ready"
  stream = `$false
  keep_alive = "12h"
} | ConvertTo-Json -Compress
try {
  Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/generate" -Method Post -ContentType "application/json" -Body `$body -TimeoutSec 600 | Out-Null
} catch {
  Start-ScheduledTask -TaskName "Ollama GPU Server"
  Start-Sleep -Seconds 8
  Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/generate" -Method Post -ContentType "application/json" -Body `$body -TimeoutSec 600 | Out-Null
}
"@ | Set-Content -Path "$scripts\warm-qwen3-14b.ps1" -Encoding UTF8

@'
$ErrorActionPreference = "Stop"

$root = "X:\Jarvis"
$service = "$root\tts-service"
$cache = "$service\cache"
$temp = "$root\temp"

New-Item -ItemType Directory -Force `
  "$service\logs", `
  $cache, `
  "$cache\uv", `
  "$cache\pip", `
  "$cache\huggingface", `
  "$cache\torch", `
  "$cache\transformers", `
  "$cache\matplotlib", `
  "$cache\numba", `
  $temp, `
  "$root\home", `
  "$root\localappdata", `
  "$root\appdata", `
  "$root\programdata" | Out-Null

$env:JARVIS_ROOT = $root
$env:HOME = "$root\home"
$env:USERPROFILE = "$root\home"
$env:LOCALAPPDATA = "$root\localappdata"
$env:APPDATA = "$root\appdata"
$env:PROGRAMDATA = "$root\programdata"
$env:PYTHONUNBUFFERED = "1"
$env:UV_CACHE_DIR = "$cache\uv"
$env:UV_PYTHON_INSTALL_DIR = "$root\python"
$env:UV_LINK_MODE = "copy"
$env:PIP_CACHE_DIR = "$cache\pip"
$env:HF_HOME = "$cache\huggingface"
$env:HF_HUB_CACHE = "$cache\huggingface\hub"
$env:TRANSFORMERS_CACHE = "$cache\transformers"
$env:TORCH_HOME = "$cache\torch"
$env:XDG_CACHE_HOME = $cache
$env:MPLCONFIGDIR = "$cache\matplotlib"
$env:NUMBA_CACHE_DIR = "$cache\numba"
$env:TEMP = $temp
$env:TMP = $temp
$env:JARVIS_VOICE_REFERENCE_ROOT = "$root\voices\chatterbox\references"

$python = "$service\.venv\Scripts\python.exe"
$out = "$service\logs\tts-server.out.log"
$err = "$service\logs\tts-server.err.log"

Start-Process `
  -FilePath $python `
  -ArgumentList "-m", "uvicorn", "jarvis_tts_server:app", "--host", "0.0.0.0", "--port", "11550" `
  -WorkingDirectory $service `
  -WindowStyle Hidden `
  -RedirectStandardOutput $out `
  -RedirectStandardError $err
'@ | Set-Content -Path "$scripts\start-jarvis-tts-hidden.ps1" -Encoding UTF8

[Environment]::SetEnvironmentVariable("OLLAMA_MODELS", $ollamaModels, "User")
[Environment]::SetEnvironmentVariable("OLLAMA_KEEP_ALIVE", "12h", "User")
[Environment]::SetEnvironmentVariable("OLLAMA_HOST", "0.0.0.0:11434", "User")
[Environment]::SetEnvironmentVariable("JARVIS_ROOT", $root, "User")
[Environment]::SetEnvironmentVariable("TEMP", $temp, "User")
[Environment]::SetEnvironmentVariable("TMP", $temp, "User")

[Environment]::SetEnvironmentVariable("OLLAMA_MODELS", $ollamaModels, "Machine")
[Environment]::SetEnvironmentVariable("OLLAMA_KEEP_ALIVE", "12h", "Machine")
[Environment]::SetEnvironmentVariable("JARVIS_ROOT", $root, "Machine")

$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
$ollamaAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument '-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "X:\Jarvis\scripts\start-ollama-gpu-hidden.ps1"'
$watchAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument '-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "X:\Jarvis\scripts\watch-ollama-gpu.ps1"'
$warmAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument '-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "X:\Jarvis\scripts\warm-qwen3-14b.ps1"'

Register-ScheduledTask -TaskName "Ollama GPU Server" -Action $ollamaAction -Trigger (New-ScheduledTaskTrigger -AtLogOn) -Principal $principal -Force | Out-Null
Register-ScheduledTask -TaskName "Ollama GPU Server Watchdog" -Action $watchAction -Trigger (New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Minutes 2) -RepetitionDuration (New-TimeSpan -Days 3650)) -Principal $principal -Force | Out-Null
Register-ScheduledTask -TaskName "Ollama Warm qwen3 14b At Logon" -Action $warmAction -Trigger (New-ScheduledTaskTrigger -AtLogOn) -Principal $principal -Force | Out-Null
Register-ScheduledTask -TaskName "Ollama Warm qwen3 14b Refresh" -Action $warmAction -Trigger (New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Hours 6) -RepetitionDuration (New-TimeSpan -Days 3650)) -Principal $principal -Force | Out-Null

Get-Process ollama -ErrorAction SilentlyContinue | Stop-Process -Force
Start-ScheduledTask -TaskName "Ollama GPU Server"

[pscustomobject]@{
  JarvisRoot = $root
  OllamaExe = "$ollamaApp\ollama.exe"
  OllamaModels = $ollamaModels
  OllamaLogs = $ollamaLogs
  Temp = $temp
  WarmScript = "$scripts\warm-qwen3-14b.ps1"
  LibreHardwareMonitor = "$tools\LibreHardwareMonitor\LibreHardwareMonitorLib.dll"
} | ConvertTo-Json
