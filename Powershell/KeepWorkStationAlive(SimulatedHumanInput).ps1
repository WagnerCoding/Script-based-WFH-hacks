Add-Type -AssemblyName System.Windows.Forms



# Define a list of possible keys
$keys = @("{F13}", "{F14}", "{F15}")

# Pick one at random
$randomKey = Get-Random -InputObject $keys

# Add user idle-time detection using Windows API
Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class IdleTimeHelper {
    [StructLayout(LayoutKind.Sequential)]
    struct LASTINPUTINFO {
        public uint cbSize;
        public uint dwTime;
    }

    [DllImport("user32.dll")]
    static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

    public static TimeSpan GetIdleTime() {
        LASTINPUTINFO lii = new LASTINPUTINFO();
        lii.cbSize = (uint)System.Runtime.InteropServices.Marshal.SizeOf(lii);
        GetLastInputInfo(ref lii);
        uint idleTime = (uint)Environment.TickCount - lii.dwTime;
        return TimeSpan.FromMilliseconds(idleTime);
    }
}
"@

# Configuration
# $delay = Get-Random -Minimum $minDelay -Maximum $maxDelay
# $idleThreshold = $delay   # 5 minutes
$hasPressed = $false
$wasIdle = $false
$prevIdle = 0          # Tracks previous idle time for activity detection

function Log($message) {
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Write-Host "[$timestamp] $message"
}

while ($true) {
    $minDelay = 30  # Minimum delay in seconds
    $maxDelay = 270 # Maximum delay in seconds
    # Pick a count of seconds that falls within the min/max range
	do {
       $delay = Get-Random -Minimum $minDelay -Maximum $maxDelay
       } while ($delay -eq $idleThreshold)
    $idleThreshold = $delay
    $idle = [IdleTimeHelper]::GetIdleTime().TotalSeconds
    $roundedIdle = [math]::Round($idle, 1)

    Log ("Idle time: {0}s" -f $roundedIdle)

    # Detect if idle timer just reset (user input occurred)
    if ($idle -lt $prevIdle) {
        Log "🔄 User active again after idle — reset trigger."
        $wasIdle = $false
        $hasPressed = $false
    }

    # If idle long enough and not already marked idle
    if ($idle -ge $idleThreshold -and -not $wasIdle) {
       	# Pick one at random and make sure it is a different option from the list than the one used in the prior iteration
	do {
		$randomKey = Get-Random -InputObject $keys
	} while ($randomKey -eq $lastkey)
	$lastKey = $randomKey
	[System.Windows.Forms.SendKeys]::SendWait($randomKey)
        Log ("✅ Pressed $randomKey after $roundedIdle seconds idle.")
        $wasIdle = $true
        $hasPressed = $true
    }

    $prevIdle = $idle
    Start-Sleep -Seconds 1
}

