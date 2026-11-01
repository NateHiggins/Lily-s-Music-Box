# Starts a windowed Godot run on its own Windows desktop, one nobody is looking at.
# A window there cannot move, clip or capture the owner's cursor, cannot take focus and
# cannot cover anything, however the game sets its mouse mode. Set
# ORISON_VISIBLE_GODOT=1 to watch a run on the real desktop instead.

if (-not ("Orison.HiddenDesktop" -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace Orison {
    public static class HiddenDesktop {
        const uint GENERIC_ALL = 0x10000000, GENERIC_WRITE = 0x40000000;
        const uint FILE_SHARE_READ = 1, FILE_SHARE_WRITE = 2, CREATE_ALWAYS = 2, OPEN_EXISTING = 3;
        const uint STARTF_USESTDHANDLES = 0x100, CREATE_NO_WINDOW = 0x08000000;

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        struct STARTUPINFO {
            public int cb; public string lpReserved; public string lpDesktop; public string lpTitle;
            public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
            public short wShowWindow, cbReserved2; public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
        }
        [StructLayout(LayoutKind.Sequential)]
        struct PROCESS_INFORMATION { public IntPtr hProcess, hThread; public int dwProcessId, dwThreadId; }
        [StructLayout(LayoutKind.Sequential)]
        struct SECURITY_ATTRIBUTES { public int nLength; public IntPtr lpSecurityDescriptor; public bool bInheritHandle; }

        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        static extern IntPtr CreateDesktopW(string name, IntPtr device, IntPtr mode, uint flags, uint access, IntPtr attributes);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        static extern bool CreateProcessW(string app, StringBuilder command, IntPtr pa, IntPtr ta, bool inherit, uint flags,
            IntPtr env, string cwd, ref STARTUPINFO si, out PROCESS_INFORMATION pi);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        static extern IntPtr CreateFileW(string path, uint access, uint share, ref SECURITY_ATTRIBUTES sa, uint disposition, uint flags, IntPtr template);
        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool CloseHandle(IntPtr handle);

        static IntPtr Output(string path) {
            var sa = new SECURITY_ATTRIBUTES { nLength = Marshal.SizeOf(typeof(SECURITY_ATTRIBUTES)), bInheritHandle = true };
            var handle = CreateFileW(path, GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, ref sa, CREATE_ALWAYS, 0, IntPtr.Zero);
            if (handle == new IntPtr(-1)) throw new IOException("cannot open " + path);
            return handle;
        }

        // The desktop handle stays open for the life of the calling runner on purpose.
        public static Process Start(string desktop, string app, string commandLine, string cwd, string stdoutPath, string stderrPath) {
            var name = desktop;
            if (CreateDesktopW(name, IntPtr.Zero, IntPtr.Zero, 0, GENERIC_ALL, IntPtr.Zero) == IntPtr.Zero)
                throw new InvalidOperationException("CreateDesktop failed: " + Marshal.GetLastWin32Error());
            var stdout = Output(stdoutPath);
            var stderr = Output(stderrPath);
            var si = new STARTUPINFO { cb = Marshal.SizeOf(typeof(STARTUPINFO)), lpDesktop = name,
                dwFlags = (int)STARTF_USESTDHANDLES, hStdOutput = stdout, hStdError = stderr };
            PROCESS_INFORMATION pi;
            var line = new StringBuilder("\"" + app + "\" " + commandLine);
            if (!CreateProcessW(app, line, IntPtr.Zero, IntPtr.Zero, true, CREATE_NO_WINDOW, IntPtr.Zero, cwd, ref si, out pi))
                throw new InvalidOperationException("CreateProcess failed: " + Marshal.GetLastWin32Error());
            var process = Process.GetProcessById(pi.dwProcessId);
            var keep = process.Handle;
            CloseHandle(pi.hThread);
            CloseHandle(pi.hProcess);
            CloseHandle(stdout);
            CloseHandle(stderr);
            return process;
        }
    }
}
'@
}

function Start-OrisonHiddenGodot {
    param([string]$Godot, [string[]]$Arguments, [string]$LogPath, [string]$ErrorPath)
    $quoted = ($Arguments | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
    $stdout = [System.IO.Path]::GetFullPath($LogPath)
    $stderr = [System.IO.Path]::GetFullPath($ErrorPath)
    return [Orison.HiddenDesktop]::Start("OrisonGodot", $Godot, $quoted, (Get-Location).Path, $stdout, $stderr)
}

function Test-OrisonHiddenGodot { return $env:ORISON_VISIBLE_GODOT -ne "1" }
