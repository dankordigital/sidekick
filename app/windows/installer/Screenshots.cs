using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;

namespace SidekickSetup
{
    /// <summary>
    /// Renders every page, light and dark, at 200 %, so the installer's look
    /// can be checked without a Windows PC (CI uploads them).
    /// </summary>
    static class Screenshots
    {
        public static void Render(string folder)
        {
            Directory.CreateDirectory(folder);
            var pages = new (string Name, Action<SetupForm> Setup)[]
            {
                ("1-welcome", f => f.installedVersion = null),
                ("2-welcome-update", f => f.installedVersion = "2.19.0"),
                ("3-welcome-permission", f => f.notice = "Windows needs your OK to install Sidekick. Click Install, then Yes."),
                ("4-privacy", f => f.page = Page.Privacy),
                ("5-installing", f =>
                {
                    f.page = Page.Working;
                    f.progress = f.shown = 0.62;
                    f.step = "Copying Sidekick…";
                }),
                ("6-done", f => f.page = Page.Done),
                ("7-failed", f =>
                {
                    f.page = Page.Failed;
                    f.error = @"Windows didn't let Sidekick change C:\Program Files\Sidekick. Close anything using that folder and try again.";
                }),
                ("8-remove", f =>
                {
                    f.removing = true;
                    f.page = Page.ConfirmRemove;
                }),
                ("9-removing", f =>
                {
                    f.removing = true;
                    f.page = Page.Working;
                    f.progress = f.shown = 0.45;
                    f.step = "Removing firewall rules…";
                }),
                ("10-removed", f =>
                {
                    f.removing = true;
                    f.page = Page.Removed;
                }),
            };
            foreach (var dark in new[] { false, true })
            {
                foreach (var (name, setup) in pages)
                {
                    using (var form = new SetupForm(new Options()))
                    {
                        form.pal = dark ? Palette.Dark : Palette.Light;
                        form.s = 2;
                        form.dir = @"C:\Program Files\Sidekick";
                        form.desktop = true;
                        form.installedVersion = null;
                        setup(form);
                        // Long enough ago that the check has popped in.
                        form.pageSince = DateTime.Now.AddSeconds(-5);
                        using (var bitmap = new Bitmap((int)(SetupForm.W * 2), (int)(SetupForm.H * 2), PixelFormat.Format24bppRgb))
                        using (var g = Graphics.FromImage(bitmap))
                        {
                            form.Render(g);
                            bitmap.Save(Path.Combine(folder, $"{name}{(dark ? "-dark" : "")}.png"), ImageFormat.Png);
                        }
                    }
                }
            }
        }
    }
}
