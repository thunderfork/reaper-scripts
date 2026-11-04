# Starts the portable test REAPER in the background, without taking the focus from the window you
# work in. Dot-source it:  . (Join-Path $PSScriptRoot "background.ps1")
#   $p = Start-BackgroundReaper "C:\REAPERtest\reaper.exe" @("-newinst", "-nosplash", "`"script.lua`"")
#   Wait-BackgroundReaper $p 120     # waits; minimises (without activating) every window it opens
Add-Type @"
using System; using System.Runtime.InteropServices; using System.Text;
public static class BgWin {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public struct STARTUPINFO { public int cb; public string r, d, t; public int x, y, w, h, cx, cy, fill, flags;
    public short show, r2; public IntPtr r3, i, o, e; }
  [StructLayout(LayoutKind.Sequential)]
  public struct PI { public IntPtr hp, ht; public int pid, tid; }
  [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
  static extern bool CreateProcess(string app, StringBuilder cmd, IntPtr pa, IntPtr ta, bool inh, int fl,
    IntPtr env, string dir, ref STARTUPINFO si, out PI pi);
  [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
  [DllImport("user32.dll")] static extern int GetWindowThreadProcessId(IntPtr h, out int pid);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int cmd);
  public static int Start(string exe, string args) {
    var si = new STARTUPINFO(); si.cb = Marshal.SizeOf(si); si.flags = 1; si.show = 7; // SW_SHOWMINNOACTIVE
    PI pi; var cmd = new StringBuilder("\"" + exe + "\" " + args);
    if (!CreateProcess(null, cmd, IntPtr.Zero, IntPtr.Zero, false, 0, IntPtr.Zero, null, ref si, out pi)) return 0;
    CloseHandle(pi.hp); CloseHandle(pi.ht); return pi.pid;
  }
  // minimises every visible, not yet minimised top-level window of the process, without activating it
  public static void Hide(int pid) {
    EnumWindows((h, l) => { int p; GetWindowThreadProcessId(h, out p);
      if (p == pid && IsWindowVisible(h) && !IsIconic(h)) ShowWindow(h, 7); return true; }, IntPtr.Zero);
  }
}
"@

function Start-BackgroundReaper([string]$exe, [string[]]$arguments) {
  $id = [BgWin]::Start($exe, ($arguments -join " "))
  if ($id -eq 0) { return $null }
  return Get-Process -Id $id -ErrorAction SilentlyContinue
}

# Waits until the process ends (true) or the timeout (false); keeps its windows minimised meanwhile.
function Wait-BackgroundReaper($p, [int]$seconds) {
  $end = (Get-Date).AddSeconds($seconds)
  while (-not $p.HasExited -and (Get-Date) -lt $end) { [BgWin]::Hide($p.Id); Start-Sleep -Milliseconds 50 }
  return $p.HasExited
}
