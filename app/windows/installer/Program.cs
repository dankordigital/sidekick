using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Security.Principal;
using System.Windows.Forms;

namespace SidekickSetup
{
    /// <summary>
    /// SidekickSetup.exe installs Sidekick; the same program built without
    /// the app inside ("Uninstall Sidekick.exe", in the app's folder)
    /// removes it.
    ///
    ///   SidekickSetup.exe                 the window
    ///   SidekickSetup.exe /S [/D=folder] [--no-desktop]   silently (needs admin)
    ///   "Uninstall Sidekick.exe" [/S]
    ///   --screenshots folder              renders every screen to PNGs (CI)
    ///   --read-aumid shortcut.lnk out.txt  writes a shortcut's AppUserModelID (CI)
    /// </summary>
    static class Program
    {
        [STAThread]
        static int Main(string[] args)
        {
            var options = Options.Parse(args);
            Log.Write($"Sidekick Setup {Payload.Version} {(Payload.Present ? "install" : "uninstall")}: {string.Join(" ", args)}");
            try
            {
                if (options.Screenshots != null)
                {
                    Screenshots.Render(options.Screenshots);
                    return 0;
                }
                if (options.ReadAumid != null)
                {
                    File.WriteAllText(options.ReadAumid.Item2, Shortcuts.ReadAumid(options.ReadAumid.Item1) ?? "");
                    return 0;
                }
                int code;
                if (options.Silent)
                {
                    code = Silent(options);
                }
                else
                {
                    Application.EnableVisualStyles();
                    Application.SetCompatibleTextRenderingDefault(false);
                    var form = new SetupForm(options);
                    Application.Run(form);
                    code = form.ExitCode;
                }
                Steps.FinishRemoval();
                return code;
            }
            catch (Exception e)
            {
                Log.Write(e.ToString());
                return 1;
            }
        }

        /// <summary>No window: for scripts, CI and updates.</summary>
        static int Silent(Options options)
        {
            if (!Elevation.IsAdmin)
            {
                // Ask once, then do it with admin rights.
                return Elevation.RunElevated(Environment.GetCommandLineArgs().Skip(1), wait: true) ?? 2;
            }
            if (Payload.Present)
            {
                var dir = options.Dir ?? Steps.Installed().Dir ?? Steps.DefaultDir;
                var desktop = !options.NoDesktop;
                Steps.Install(dir, desktop, (f, what) => { });
            }
            else
            {
                Steps.Uninstall(Steps.OwnDir, (f, what) => { });
            }
            return 0;
        }
    }

    /// <summary>What the command line asked for.</summary>
    class Options
    {
        public bool Silent;
        public string Dir;
        public bool NoDesktop;

        /// <summary>Start at once (the copy started with admin rights).</summary>
        public bool Go;

        /// <summary>Where the first window was, so this one opens there.</summary>
        public System.Drawing.Point? Position;

        public string Screenshots;
        public Tuple<string, string> ReadAumid;

        public static Options Parse(string[] args)
        {
            var o = new Options();
            for (var i = 0; i < args.Length; i++)
            {
                var a = args[i];
                string Next() => i + 1 < args.Length ? args[++i] : null;
                switch (a.ToLowerInvariant())
                {
                    case "/s":
                    case "/silent":
                    case "/verysilent":
                    case "--silent":
                        o.Silent = true;
                        break;
                    case "--dir":
                        o.Dir = Next();
                        break;
                    case "--no-desktop":
                        o.NoDesktop = true;
                        break;
                    case "--go":
                        o.Go = true;
                        break;
                    case "--pos":
                        var xy = (Next() ?? "").Split(',');
                        if (xy.Length == 2 && int.TryParse(xy[0], out var x) && int.TryParse(xy[1], out var y))
                        {
                            o.Position = new System.Drawing.Point(x, y);
                        }
                        break;
                    case "--screenshots":
                        o.Screenshots = Next();
                        break;
                    case "--read-aumid":
                        var link = Next();
                        var output = Next();
                        if (link != null && output != null) o.ReadAumid = Tuple.Create(link, output);
                        break;
                    default:
                        // Inno Setup's way of naming the folder: /D=C:\Apps\Sidekick
                        if (a.StartsWith("/D=", StringComparison.OrdinalIgnoreCase)) o.Dir = a.Substring(3);
                        break;
                }
            }
            return o;
        }
    }

    /// <summary>The app, zipped inside SidekickSetup.exe.</summary>
    static class Payload
    {
        public static bool Present => Assembly.GetExecutingAssembly().GetManifestResourceInfo("payload.zip") != null;

        public static Stream Open() => Assembly.GetExecutingAssembly().GetManifestResourceStream("payload.zip");

        /// <summary>"3.0.0", from the version CI builds it with.</summary>
        public static string Version
        {
            get
            {
                var v = Assembly.GetExecutingAssembly().GetName().Version;
                return $"{v.Major}.{v.Minor}.{v.Build}";
            }
        }

        public static Stream Resource(string name) => Assembly.GetExecutingAssembly().GetManifestResourceStream(name);
    }

    static class Elevation
    {
        public static bool IsAdmin
        {
            get
            {
                using (var identity = WindowsIdentity.GetCurrent())
                {
                    return new WindowsPrincipal(identity).IsInRole(WindowsBuiltInRole.Administrator);
                }
            }
        }

        /// <summary>
        /// Starts this program again with admin rights (Windows asks). Null
        /// when the person said no.
        /// </summary>
        public static int? RunElevated(System.Collections.Generic.IEnumerable<string> args, bool wait)
        {
            var info = new ProcessStartInfo(Application.ExecutablePath, string.Join(" ", args.Select(Quote)))
            {
                UseShellExecute = true,
                Verb = "runas",
            };
            try
            {
                using (var p = Process.Start(info))
                {
                    if (!wait) return 0;
                    p.WaitForExit();
                    return p.ExitCode;
                }
            }
            catch (Win32Exception e) when (e.NativeErrorCode == 1223)
            {
                // ERROR_CANCELLED: "No" in the permission prompt.
                return null;
            }
        }

        public static Process StartElevated(System.Collections.Generic.IEnumerable<string> args)
        {
            var info = new ProcessStartInfo(Application.ExecutablePath, string.Join(" ", args.Select(Quote)))
            {
                UseShellExecute = true,
                Verb = "runas",
            };
            try
            {
                return Process.Start(info);
            }
            catch (Win32Exception e) when (e.NativeErrorCode == 1223)
            {
                return null;
            }
        }

        public static string Quote(string arg) =>
            arg.Length > 0 && arg.IndexOfAny(new[] { ' ', '\t', '"' }) < 0 ? arg : "\"" + arg.Replace("\"", "\\\"") + "\"";
    }

    /// <summary>%TEMP%\SidekickSetup.log: what happened, for when something fails.</summary>
    static class Log
    {
        public static readonly string Path = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "SidekickSetup.log");

        public static void Write(string line)
        {
            try
            {
                File.AppendAllText(Path, $"{DateTime.Now:yyyy-MM-dd HH:mm:ss} {line}{Environment.NewLine}");
            }
            catch
            {
                // Logging never stops the installer.
            }
        }
    }
}
