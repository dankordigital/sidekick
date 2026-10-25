using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Runtime.InteropServices;
using Microsoft.Win32;

namespace SidekickSetup
{
    /// <summary>How far along (0 to 1) and what's happening, for the window.</summary>
    delegate void Report(double fraction, string what);

    /// <summary>What installing and removing Sidekick does.</summary>
    static class Steps
    {
        public const string AppName = "Sidekick";
        public const string Exe = "sidekick.exe";
        public const string UninstallerName = "Uninstall Sidekick.exe";

        /// <summary>Toasts (phone notifications on the PC) are shown under this name.</summary>
        public const string Aumid = "Sidekick.Sidekick";

        const string UninstallKey = @"Software\Microsoft\Windows\CurrentVersion\Uninstall\Sidekick";

        /// <summary>Where the Inno Setup installer (up to 3.0.0) registered Sidekick.</summary>
        const string InnoKey = @"Software\Microsoft\Windows\CurrentVersion\Uninstall\{8F3C2A51-6B7E-4D2F-9C1A-5E4B3D2F1A60}_is1";

        const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";

        public static string DefaultDir =>
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), AppName);

        /// <summary>The folder this program runs from (the uninstaller's: the app's).</summary>
        public static string OwnDir => Path.GetDirectoryName(System.Windows.Forms.Application.ExecutablePath);

        static RegistryKey Machine => RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, RegistryView.Registry64);

        /// <summary>Sidekick already on this PC: where, and which version.</summary>
        public static (string Dir, string Version) Installed()
        {
            foreach (var name in new[] { UninstallKey, InnoKey })
            {
                try
                {
                    using (var key = Machine.OpenSubKey(name))
                    {
                        var dir = (key?.GetValue("InstallLocation") as string)?.TrimEnd('\\');
                        if (!string.IsNullOrEmpty(dir) && File.Exists(Path.Combine(dir, Exe)))
                        {
                            return (dir, key.GetValue("DisplayVersion") as string);
                        }
                    }
                }
                catch (Exception e)
                {
                    Log.Write($"Reading {name}: {e.Message}");
                }
            }
            return (null, null);
        }

        public static string DesktopShortcut =>
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonDesktopDirectory), AppName + ".lnk");

        static string StartMenuShortcut =>
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonPrograms), AppName + ".lnk");

        /// <summary>
        /// A folder Sidekick can go in: empty, new, or Sidekick's own. Never
        /// one with other things in it, since an update replaces it whole.
        /// </summary>
        public static string CheckFolder(string dir)
        {
            if (string.IsNullOrWhiteSpace(dir)) return "Pick a folder for Sidekick.";
            string full;
            try
            {
                full = Path.GetFullPath(dir);
            }
            catch (Exception)
            {
                return "That isn't a folder Sidekick can use.";
            }
            if (Path.GetPathRoot(full).TrimEnd('\\') == full.TrimEnd('\\')) return "Sidekick needs a folder of its own, not a whole drive.";
            if (Directory.Exists(full) && Directory.EnumerateFileSystemEntries(full).Any() && !File.Exists(Path.Combine(full, Exe)))
            {
                return "That folder has other things in it. Pick an empty one, or a new one.";
            }
            return null;
        }

        // ------------------------------------------------------------ install

        public static void Install(string dir, bool desktop, Report report)
        {
            dir = Path.GetFullPath(dir).TrimEnd('\\');
            var problem = CheckFolder(dir);
            if (problem != null) throw new InvalidOperationException(problem);
            Log.Write($"Installing {Payload.Version} into {dir} (desktop shortcut: {desktop})");

            report(0.02, "Closing Sidekick…");
            StopSidekick(dir);

            // Unpacked next to the old one first, then swapped in, so a
            // failure half-way leaves the old Sidekick working.
            var staging = dir + ".new";
            var old = dir + ".old";
            DeleteQuietly(staging);
            DeleteQuietly(old);
            Directory.CreateDirectory(staging);
            Extract(staging, report, 0.05, 0.75);

            report(0.82, "Putting Sidekick in place…");
            if (Directory.Exists(dir))
            {
                try
                {
                    Directory.Move(dir, old);
                }
                catch (IOException e)
                {
                    // Something still holds a file there (a window showing
                    // the folder): copy over the old files instead.
                    Log.Write($"Couldn't move the old folder ({e.Message}); copying over it");
                    CopyOver(staging, dir);
                    DeleteQuietly(staging);
                    staging = null;
                }
            }
            if (staging != null) Directory.Move(staging, dir);
            DeleteQuietly(old);

            report(0.88, "Adding shortcuts…");
            var exe = Path.Combine(dir, Exe);
            Shortcuts.Create(StartMenuShortcut, exe, Aumid);
            if (desktop)
            {
                Shortcuts.Create(DesktopShortcut, exe, null);
            }
            else if (File.Exists(DesktopShortcut))
            {
                File.Delete(DesktopShortcut);
            }

            report(0.93, "Letting your devices reach Sidekick…");
            AllowThroughFirewall(exe);

            report(0.97, "Finishing…");
            Register(dir);
            report(1, "Done");
            Log.Write("Installed");
        }

        /// <summary>Stops a running Sidekick from [dir], so its files can be replaced.</summary>
        static void StopSidekick(string dir)
        {
            foreach (var p in Process.GetProcessesByName(Path.GetFileNameWithoutExtension(Exe)))
            {
                using (p)
                {
                    try
                    {
                        string path = null;
                        try
                        {
                            path = p.MainModule?.FileName;
                        }
                        catch
                        {
                            // Another user's: the path can't be read. Stop it too, to be safe.
                        }
                        if (path != null && !path.StartsWith(dir + "\\", StringComparison.OrdinalIgnoreCase)) continue;
                        p.Kill();
                        p.WaitForExit(5000);
                        Log.Write($"Stopped Sidekick ({p.Id})");
                    }
                    catch (Exception e)
                    {
                        Log.Write($"Couldn't stop Sidekick: {e.Message}");
                    }
                }
            }
        }

        static void Extract(string to, Report report, double from, double span)
        {
            using (var zip = new ZipArchive(Payload.Open(), ZipArchiveMode.Read))
            {
                var root = Path.GetFullPath(to).TrimEnd('\\') + "\\";
                long total = Math.Max(1, zip.Entries.Sum(e => e.Length));
                long done = 0;
                var lastReport = DateTime.MinValue;
                var buffer = new byte[1 << 17];
                foreach (var entry in zip.Entries)
                {
                    var name = entry.FullName.Replace('/', '\\');
                    var target = Path.GetFullPath(Path.Combine(to, name));
                    if (!target.StartsWith(root, StringComparison.OrdinalIgnoreCase))
                    {
                        throw new InvalidDataException("The installer is damaged. Download it again.");
                    }
                    if (name.EndsWith("\\"))
                    {
                        Directory.CreateDirectory(target);
                        continue;
                    }
                    Directory.CreateDirectory(Path.GetDirectoryName(target));
                    using (var src = entry.Open())
                    using (var dst = File.Create(target))
                    {
                        int n;
                        while ((n = src.Read(buffer, 0, buffer.Length)) > 0)
                        {
                            dst.Write(buffer, 0, n);
                            done += n;
                            if ((DateTime.Now - lastReport).TotalMilliseconds > 50)
                            {
                                lastReport = DateTime.Now;
                                report(from + span * done / total, "Copying Sidekick…");
                            }
                        }
                    }
                }
            }
        }

        static void CopyOver(string from, string to)
        {
            foreach (var file in Directory.EnumerateFiles(from, "*", SearchOption.AllDirectories))
            {
                var target = Path.Combine(to, file.Substring(from.Length + 1));
                Directory.CreateDirectory(Path.GetDirectoryName(target));
                File.Copy(file, target, true);
            }
        }

        /// <summary>
        /// Lets other devices on private networks reach Sidekick, so Windows
        /// Firewall neither blocks it nor asks on its first start. A phone's
        /// direct-link hotspot counts as a public network, so the local
        /// subnet is allowed there too (everything past /v1/info still needs
        /// pairing). Old rules go first, so updates don't pile up copies.
        /// </summary>
        static void AllowThroughFirewall(string exe)
        {
            Netsh($"advfirewall firewall delete rule name=\"{AppName}\"");
            Netsh($"advfirewall firewall add rule name=\"{AppName}\" dir=in action=allow program=\"{exe}\" enable=yes profile=private,domain");
            Netsh($"advfirewall firewall delete rule name=\"{AppName} direct link\"");
            Netsh($"advfirewall firewall add rule name=\"{AppName} direct link\" dir=in action=allow program=\"{exe}\" enable=yes profile=public remoteip=localsubnet");
        }

        static void Netsh(string args)
        {
            try
            {
                var info = new ProcessStartInfo(Path.Combine(Environment.SystemDirectory, "netsh.exe"), args)
                {
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                };
                using (var p = Process.Start(info))
                {
                    var output = p.StandardOutput.ReadToEnd().Trim();
                    p.WaitForExit(15000);
                    Log.Write($"netsh {args}: {p.ExitCode} {output}");
                }
            }
            catch (Exception e)
            {
                Log.Write($"netsh {args}: {e.Message}");
            }
        }

        /// <summary>Settings → Apps lists Sidekick, with Uninstall.</summary>
        static void Register(string dir)
        {
            var uninstaller = Path.Combine(dir, UninstallerName);
            long bytes = 0;
            foreach (var f in Directory.EnumerateFiles(dir, "*", SearchOption.AllDirectories)) bytes += new FileInfo(f).Length;
            using (var machine = Machine)
            {
                using (var key = machine.CreateSubKey(UninstallKey))
                {
                    key.SetValue("DisplayName", AppName);
                    key.SetValue("DisplayVersion", Payload.Version);
                    key.SetValue("Publisher", AppName);
                    key.SetValue("DisplayIcon", Path.Combine(dir, Exe));
                    key.SetValue("InstallLocation", dir);
                    key.SetValue("UninstallString", $"\"{uninstaller}\"");
                    key.SetValue("QuietUninstallString", $"\"{uninstaller}\" /S");
                    key.SetValue("URLInfoAbout", "https://getsidekick.app");
                    key.SetValue("HelpLink", "https://github.com/dankordigital/sidekick/issues");
                    key.SetValue("InstallDate", DateTime.Now.ToString("yyyyMMdd"));
                    key.SetValue("EstimatedSize", (int)(bytes / 1024), RegistryValueKind.DWord);
                    key.SetValue("NoModify", 1, RegistryValueKind.DWord);
                    key.SetValue("NoRepair", 1, RegistryValueKind.DWord);
                }
                // The Inno Setup installer's entry: its uninstaller went with
                // the old folder, so the entry would lead nowhere.
                machine.DeleteSubKeyTree(InnoKey, false);
            }
        }

        // ---------------------------------------------------------- uninstall

        /// <summary>The app's folder, removed once this program has quit.</summary>
        static string _removeAtExit;

        /// <summary>Where Sidekick keeps settings, pairings and its keys (%APPDATA%\Sidekick).</summary>
        static string DataDir => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), AppName);

        /// <summary>
        /// Removes Sidekick; with [forget], also its settings, paired devices
        /// and keys (the privacy policy says removing Sidekick removes them).
        /// </summary>
        public static void Uninstall(string dir, bool forget, Report report)
        {
            dir = Path.GetFullPath(dir).TrimEnd('\\');
            Log.Write($"Removing Sidekick from {dir}");
            report(0.1, "Closing Sidekick…");
            StopSidekick(dir);

            report(0.3, "Removing shortcuts…");
            foreach (var link in new[] { StartMenuShortcut, DesktopShortcut })
            {
                try
                {
                    if (File.Exists(link)) File.Delete(link);
                }
                catch (Exception e)
                {
                    Log.Write($"Deleting {link}: {e.Message}");
                }
            }

            report(0.45, "Removing firewall rules…");
            Netsh($"advfirewall firewall delete rule name=\"{AppName}\"");
            Netsh($"advfirewall firewall delete rule name=\"{AppName} direct link\"");

            report(0.6, "Removing settings from Windows…");
            try
            {
                // Starting with Windows (Settings → Auto-load).
                using (var run = Registry.CurrentUser.OpenSubKey(RunKey, true)) run?.DeleteValue(AppName, false);
                using (var machine = Machine)
                {
                    machine.DeleteSubKeyTree(UninstallKey, false);
                    machine.DeleteSubKeyTree(InnoKey, false);
                }
            }
            catch (Exception e)
            {
                Log.Write($"Registry: {e.Message}");
            }

            if (forget)
            {
                report(0.7, "Forgetting paired devices and settings…");
                try
                {
                    if (Directory.Exists(DataDir)) Directory.Delete(DataDir, true);
                }
                catch (Exception e)
                {
                    Log.Write($"Deleting {DataDir}: {e.Message}");
                }
            }

            report(0.75, "Removing Sidekick's files…");
            // Only ever a folder that holds Sidekick.
            if (File.Exists(Path.Combine(dir, Exe)) && CheckFolder(dir) == null)
            {
                var self = System.Windows.Forms.Application.ExecutablePath;
                foreach (var entry in Directory.EnumerateFileSystemEntries(dir))
                {
                    if (string.Equals(entry, self, StringComparison.OrdinalIgnoreCase)) continue;
                    try
                    {
                        if (Directory.Exists(entry))
                        {
                            Directory.Delete(entry, true);
                        }
                        else
                        {
                            File.Delete(entry);
                        }
                    }
                    catch (Exception e)
                    {
                        Log.Write($"Deleting {entry}: {e.Message}");
                    }
                }
                _removeAtExit = dir;
            }
            report(1, "Done");
            Log.Write("Removed");
        }

        /// <summary>
        /// The uninstaller runs from the folder it removes, so the folder
        /// (and the uninstaller) go a moment after it quits.
        /// </summary>
        public static void FinishRemoval()
        {
            var dir = _removeAtExit;
            if (dir == null) return;
            try
            {
                var info = new ProcessStartInfo(
                    Path.Combine(Environment.SystemDirectory, "cmd.exe"),
                    $"/d /c ping 127.0.0.1 -n 3 > nul & rmdir /s /q \"{dir}\"")
                {
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    WorkingDirectory = Path.GetTempPath(),
                };
                Process.Start(info)?.Dispose();
            }
            catch (Exception e)
            {
                Log.Write($"Removing {dir}: {e.Message}");
            }
        }

        // ------------------------------------------------------------ helpers

        static void DeleteQuietly(string dir)
        {
            if (!Directory.Exists(dir)) return;
            try
            {
                Directory.Delete(dir, true);
            }
            catch (Exception e)
            {
                // Still in use: gone after the next restart.
                Log.Write($"Deleting {dir}: {e.Message}; after a restart instead");
                foreach (var f in Directory.EnumerateFiles(dir, "*", SearchOption.AllDirectories))
                {
                    MoveFileEx(f, null, MoveFileDelayUntilReboot);
                }
                MoveFileEx(dir, null, MoveFileDelayUntilReboot);
            }
        }

        /// <summary>Starts Sidekick as the person (not with this installer's admin rights).</summary>
        public static void Launch(string dir)
        {
            var exe = Path.Combine(dir, Exe);
            try
            {
                // Explorer starts it the way a double-click would: without
                // admin rights, so drag and drop from other windows works.
                Process.Start(new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), "explorer.exe"), $"\"{exe}\"")
                {
                    UseShellExecute = false,
                })?.Dispose();
            }
            catch (Exception e)
            {
                Log.Write($"Starting Sidekick: {e.Message}");
            }
        }

        const int MoveFileDelayUntilReboot = 4;

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        static extern bool MoveFileEx(string existing, string replacement, int flags);
    }
}
