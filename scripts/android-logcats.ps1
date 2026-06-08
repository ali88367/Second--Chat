# Filtered adb logcat for Second Chat debugging.
#
# Open 2 focused windows (recommended):
#   .\scripts\android-logcats.ps1
#
# Run one stream in THIS terminal:
#   .\scripts\android-logcats.ps1 -Stream broadcast
#   .\scripts\android-logcats.ps1 -Stream crashes
#
# Copy-paste one-liners (no script needed):
#   adb logcat -v time flutter:V *:S | Select-String -Pattern 'HTTP|broadcast|RTMP|publish|platformLive|StreamWebView|PiP|Exception|Error|MissingPlugin|connection|LIVE'
#   adb logcat -v time AndroidRuntime:E flutter:E *:S

param(
    [ValidateSet('all', 'broadcast', 'crashes')]
    [string]$Stream = 'all'
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    Write-Error 'adb not found. Add Android SDK platform-tools to PATH.'
}

$devices = @(adb devices | Select-String '^\S+\s+device$' | ForEach-Object { $_.Line.Split()[0] })
if ($devices.Count -eq 0) {
    Write-Error 'No Android device connected.'
}

$broadcastFilter = @(
    'HTTP',
    'broadcast',
    'RTMP',
    'publish',
    'platformLive',
    'StreamWebView',
    'PiP',
    'GoLive',
    'Exception',
    'Error',
    'MissingPlugin',
    'connection',
    'LIVE',
    'apivideo',
    'streampack'
) -join '|'

function Start-LogcatWindow {
    param(
        [string]$Title,
        [string]$Command
    )
    $encoded = [Convert]::ToBase64String(
        [Text.Encoding]::Unicode.GetBytes(
            "`$Host.UI.RawUI.WindowTitle = '$Title'; $Command"
        )
    )
    Start-Process powershell.exe -ArgumentList '-NoExit', '-EncodedCommand', $encoded
}

function Start-BroadcastLogcat {
    adb logcat -v time flutter:V *:S |
        Select-String -Pattern $broadcastFilter -CaseSensitive:$false
}

function Start-CrashLogcat {
    adb logcat -v time AndroidRuntime:E flutter:E *:S
}

switch ($Stream) {
    'broadcast' {
        Write-Host "Broadcast/API logcat on device $($devices[0]). Ctrl+C to stop."
        Start-BroadcastLogcat
    }
    'crashes' {
        Write-Host "Crash logcat on device $($devices[0]). Ctrl+C to stop."
        Start-CrashLogcat
    }
    'all' {
        Write-Host "Device: $($devices[0])"
        Write-Host 'Opening 2 logcat windows (broadcast + crashes)...'
        Start-LogcatWindow -Title 'Logcat: Broadcast + API' -Command @"
adb logcat -v time flutter:V *:S | Select-String -Pattern '$broadcastFilter' -CaseSensitive:`$false
"@
        Start-LogcatWindow -Title 'Logcat: Crashes' -Command @'
adb logcat -v time AndroidRuntime:E flutter:E *:S
'@
        Write-Host 'Done. Close each window to stop that stream.'
        Write-Host ''
        Write-Host 'Run in this terminal instead:'
        Write-Host '  .\scripts\android-logcats.ps1 -Stream broadcast'
        Write-Host '  .\scripts\android-logcats.ps1 -Stream crashes'
    }
}
