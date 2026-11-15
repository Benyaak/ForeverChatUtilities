# Optional companion helper for Forever Chat Utilities (Windows PowerShell).
# When World of Warcraft is the active window and you copy an http(s) URL
# from the in-game navigation dialog (Ctrl+C), this helper opens it in your
# default web browser automatically.

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class WowWinFocus {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
}
"@

function Test-WowFrontmost {
    $hwnd = [WowWinFocus]::GetForegroundWindow()
    if ($hwnd -eq [IntPtr]::Zero) { return $false }
    [uint32]$pidOut = 0
    [void][WowWinFocus]::GetWindowThreadProcessId($hwnd, [ref]$pidOut)
    if ($pidOut -eq 0) { return $false }
    try {
        $proc = Get-Process -Id $pidOut -ErrorAction Stop
        return ($proc.ProcessName -like "Wow*")
    } catch {
        return $false
    }
}

Write-Host "Forever Chat Utilities - Browser Link Helper (Windows)"
Write-Host "Listening for URLs copied from World of Warcraft... Press Ctrl+C to stop."

$lastClip = Get-Clipboard -Raw -ErrorAction SilentlyContinue

while ($true) {
    $clip = Get-Clipboard -Raw -ErrorAction SilentlyContinue
    if ($clip) { $clip = $clip.Trim() }

    if (-not [string]::IsNullOrEmpty($clip) -and $clip -ne $lastClip) {
        $lastClip = $clip
        if ((Test-WowFrontmost) -and ($clip -match '^https?://[^\s<>"]+$')) {
            Write-Host "Opening: $clip"
            Start-Process $clip
        }
    }

    Start-Sleep -Milliseconds 400
}
