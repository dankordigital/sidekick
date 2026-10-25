using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Win32;

namespace SidekickSetup
{
    enum Page { Welcome, Privacy, Working, Done, Failed, ConfirmRemove, Removed }

    /// <summary>Sidekick's colors (the website's), light and dark.</summary>
    class Palette
    {
        public Color Surface, Card, Line, Text, Muted, Primary, OnPrimary, PrimarySoft, OnPrimarySoft, Success, Danger;

        public static readonly Palette Light = new Palette
        {
            Surface = Hex(0xFAF9FE),
            Card = Hex(0xF1F0F8),
            Line = Hex(0xE2E0EE),
            Text = Hex(0x1A1A20),
            Muted = Hex(0x5B5A66),
            Primary = Hex(0x654DB6),
            OnPrimary = Color.White,
            PrimarySoft = Hex(0xE0DBFF),
            OnPrimarySoft = Hex(0x33235F),
            Success = Hex(0x1E9E5A),
            Danger = Hex(0xC62828),
        };

        public static readonly Palette Dark = new Palette
        {
            Surface = Hex(0x111016),
            Card = Hex(0x1B1A22),
            Line = Hex(0x2C2B35),
            Text = Hex(0xEBEAF0),
            Muted = Hex(0xADACB8),
            Primary = Hex(0xBCB3FA),
            OnPrimary = Hex(0x2A1C56),
            PrimarySoft = Hex(0x3A2D6B),
            OnPrimarySoft = Hex(0xE7E2FF),
            Success = Hex(0x4ADE80),
            Danger = Hex(0xFF8A80),
        };

        /// <summary>Follows Windows' "app mode" (Settings → Personalization → Colors).</summary>
        public static Palette ForSystem()
        {
            try
            {
                using (var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"))
                {
                    if (key?.GetValue("AppsUseLightTheme") is int light && light == 0) return Dark;
                }
            }
            catch
            {
                // Light, then.
            }
            return Light;
        }

        static Color Hex(int rgb) => Color.FromArgb(255, (rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF);

        public static Color Mix(Color a, Color b, double t) => Color.FromArgb(
            255,
            (int)(a.R + (b.R - a.R) * t),
            (int)(a.G + (b.G - a.G) * t),
            (int)(a.B + (b.B - a.B) * t));
    }

    /// <summary>
    /// The installer's one window: drawn entirely by hand in Sidekick's
    /// look, one page at a time (welcome, installing, done; or, as the
    /// uninstaller, remove, removing, removed).
    /// </summary>
    class SetupForm : Form
    {
        /// <summary>The window's size at 100 % scaling.</summary>
        public const float W = 420, H = 560;

        public int ExitCode;

        internal Palette pal = Palette.ForSystem();
        internal float s = 1;
        internal Page page;
        internal bool removing;
        internal string dir;
        internal bool desktop = true;

        /// <summary>The version already on this PC (an update), if any.</summary>
        internal string installedVersion;

        internal double progress, shown;
        internal string step = "";
        internal string error;

        /// <summary>A line above the main button (why it didn't go ahead).</summary>
        internal string notice;

        internal DateTime pageSince = DateTime.Now;
        int scroll;

        readonly Options options;
        readonly Image logo;
        readonly string privacy;
        readonly List<(RectangleF Rect, string Id, Action Click)> hits = new List<(RectangleF, string, Action)>();
        readonly Dictionary<(float, bool), Font> fonts = new Dictionary<(float, bool), Font>();
        readonly Timer tick = new Timer { Interval = 15 };
        string hover, pressed;

        public SetupForm(Options options)
        {
            this.options = options;
            removing = !Payload.Present;
            var installed = removing ? (Dir: (string)null, Version: (string)null) : Steps.Installed();
            dir = removing ? Steps.OwnDir : options.Dir ?? installed.Dir ?? Steps.DefaultDir;
            installedVersion = installed.Version;
            // An update keeps the desktop shortcut the way it was.
            desktop = options.Go || installed.Dir == null ? !options.NoDesktop : File.Exists(Steps.DesktopShortcut);
            page = removing ? Page.ConfirmRemove : Page.Welcome;

            // A copy: a Bitmap made from a stream needs the stream for its whole life.
            using (var stream = Payload.Resource("logo.png"))
            using (var image = new Bitmap(stream))
            {
                logo = new Bitmap(image);
            }
            using (var reader = new StreamReader(Payload.Resource("privacy.txt"))) privacy = reader.ReadToEnd().Trim();

            Text = removing ? "Uninstall Sidekick" : "Sidekick Setup";
            FormBorderStyle = FormBorderStyle.None;
            AutoScaleMode = AutoScaleMode.None;
            KeyPreview = true;
            BackColor = pal.Surface;
            try
            {
                Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
            }
            catch
            {
                // The default icon, then.
            }
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer, true);
            using (var g = CreateGraphics()) s = g.DpiX / 96f;
            ClientSize = new Size((int)(W * s), (int)(H * s));
            if (options.Position is Point p)
            {
                StartPosition = FormStartPosition.Manual;
                Location = p;
            }
            else
            {
                StartPosition = FormStartPosition.CenterScreen;
            }
            tick.Tick += (sender, e) => Animate();
        }

        protected override CreateParams CreateParams
        {
            get
            {
                var p = base.CreateParams;
                p.ClassStyle |= 0x00020000; // CS_DROPSHADOW
                p.Style |= 0x00020000; // WS_MINIMIZEBOX: a click on the taskbar button minimizes it
                return p;
            }
        }

        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            // Windows 11: rounded corners like every other window.
            try
            {
                var round = 2;
                DwmSetWindowAttribute(Handle, 33, ref round, sizeof(int));
            }
            catch
            {
                // Windows 10: square corners.
            }
        }

        protected override void OnShown(EventArgs e)
        {
            base.OnShown(e);
            Activate();
            // The copy started with admin rights goes straight to work.
            if (options.Go) Work();
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            if (page == Page.Working && e.CloseReason == CloseReason.UserClosing) e.Cancel = true;
            base.OnFormClosing(e);
        }

        // ---------------------------------------------------------- actions

        void SetPage(Page next)
        {
            page = next;
            pageSince = DateTime.Now;
            hover = null;
            scroll = 0;
            tick.Start();
            Invalidate();
        }

        /// <summary>Install (or Remove): with admin rights, or after Windows gives them.</summary>
        void Go()
        {
            notice = null;
            if (!removing)
            {
                var problem = Steps.CheckFolder(dir);
                if (problem != null)
                {
                    notice = problem;
                    Invalidate();
                    return;
                }
            }
            if (!Elevation.IsAdmin)
            {
                var args = new List<string> { "--go", "--pos", $"{Left},{Top}" };
                if (!removing)
                {
                    args.Add("--dir");
                    args.Add(dir);
                    if (!desktop) args.Add("--no-desktop");
                }
                var child = Elevation.StartElevated(args);
                if (child == null)
                {
                    notice = removing
                        ? "Windows needs your OK to remove Sidekick. Click Remove, then Yes."
                        : "Windows needs your OK to install Sidekick. Click Install, then Yes.";
                    Invalidate();
                    return;
                }
                // That copy carries on in the same place; this one waits.
                Hide();
                child.EnableRaisingEvents = true;
                child.Exited += (sender, e) => BeginInvoke(new Action(() =>
                {
                    ExitCode = child.ExitCode;
                    Close();
                }));
                return;
            }
            Work();
        }

        async void Work()
        {
            progress = shown = 0;
            step = "Getting ready…";
            error = null;
            SetPage(Page.Working);
            try
            {
                Report report = (f, what) => BeginInvoke(new Action(() =>
                {
                    progress = f;
                    step = what;
                }));
                if (removing)
                {
                    await Task.Run(() => Steps.Uninstall(dir, report));
                }
                else
                {
                    await Task.Run(() => Steps.Install(dir, desktop, report));
                }
                progress = 1;
                // Let the bar fill before the next page.
                await Task.Delay(400);
                SetPage(removing ? Page.Removed : Page.Done);
            }
            catch (Exception e)
            {
                Log.Write(e.ToString());
                error = Describe(e);
                ExitCode = 1;
                SetPage(Page.Failed);
            }
        }

        string Describe(Exception e)
        {
            switch (e)
            {
                case UnauthorizedAccessException _:
                    return $"Windows didn't let Sidekick change {dir}. Close anything using that folder and try again.";
                case InvalidOperationException _:
                case IOException _:
                case InvalidDataException _:
                    return e.Message;
                default:
                    return "Something went wrong: " + e.Message;
            }
        }

        void PickFolder()
        {
            using (var dialog = new FolderBrowserDialog
            {
                Description = "Where should Sidekick go? It gets a folder of its own there.",
                ShowNewFolderButton = true,
            })
            {
                var parent = Path.GetDirectoryName(dir);
                if (Directory.Exists(parent)) dialog.SelectedPath = parent;
                if (dialog.ShowDialog(this) != DialogResult.OK) return;
                var chosen = dialog.SelectedPath;
                // Always its own folder, never loose files in the one picked.
                dir = string.Equals(Path.GetFileName(chosen.TrimEnd('\\')), Steps.AppName, StringComparison.OrdinalIgnoreCase)
                    ? chosen
                    : Path.Combine(chosen, Steps.AppName);
                notice = Steps.CheckFolder(dir);
                Invalidate();
            }
        }

        void OpenSidekick()
        {
            Steps.Launch(dir);
            Close();
        }

        /// <summary>Enter.</summary>
        void Primary()
        {
            switch (page)
            {
                case Page.Welcome:
                case Page.ConfirmRemove:
                    Go();
                    break;
                case Page.Privacy:
                    SetPage(Page.Welcome);
                    break;
                case Page.Done:
                    OpenSidekick();
                    break;
                case Page.Failed:
                    SetPage(removing ? Page.ConfirmRemove : Page.Welcome);
                    break;
                case Page.Removed:
                    Close();
                    break;
            }
        }

        void Animate()
        {
            shown += (progress - shown) * 0.16;
            var settling = Math.Abs(progress - shown) > 0.001;
            var popping = (DateTime.Now - pageSince).TotalMilliseconds < 700;
            if (!settling && !popping && page != Page.Working) tick.Stop();
            Invalidate();
        }

        // ------------------------------------------------------------- input

        protected override void OnKeyDown(KeyEventArgs e)
        {
            base.OnKeyDown(e);
            if (e.KeyCode == Keys.Enter)
            {
                Primary();
            }
            else if (e.KeyCode == Keys.Escape)
            {
                if (page == Page.Privacy)
                {
                    SetPage(Page.Welcome);
                }
                else if (page != Page.Working)
                {
                    Close();
                }
            }
        }

        string HitAt(Point p)
        {
            for (var i = hits.Count - 1; i >= 0; i--)
            {
                if (hits[i].Rect.Contains(p)) return hits[i].Id;
            }
            return null;
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            base.OnMouseMove(e);
            var id = HitAt(e.Location);
            Cursor = id != null ? Cursors.Hand : Cursors.Default;
            if (id == hover) return;
            hover = id;
            Invalidate();
        }

        protected override void OnMouseLeave(EventArgs e)
        {
            base.OnMouseLeave(e);
            hover = null;
            Invalidate();
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            base.OnMouseDown(e);
            if (e.Button != MouseButtons.Left) return;
            pressed = HitAt(e.Location);
            if (pressed == null)
            {
                // Anywhere else moves the window.
                ReleaseCapture();
                SendMessage(Handle, 0xA1, (IntPtr)2, IntPtr.Zero);
                return;
            }
            Invalidate();
        }

        protected override void OnMouseUp(MouseEventArgs e)
        {
            base.OnMouseUp(e);
            var id = HitAt(e.Location);
            var was = pressed;
            pressed = null;
            Invalidate();
            if (id == null || id != was) return;
            hits.FirstOrDefault(h => h.Id == id).Click?.Invoke();
        }

        protected override void OnMouseWheel(MouseEventArgs e)
        {
            base.OnMouseWheel(e);
            if (page != Page.Privacy) return;
            scroll = Math.Max(0, scroll - (int)(e.Delta / 120f * 48 * s));
            Invalidate();
        }

        // ----------------------------------------------------------- drawing

        protected override void OnPaint(PaintEventArgs e) => Render(e.Graphics);

        internal void Render(Graphics g)
        {
            hits.Clear();
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.Clear(pal.Surface);
            switch (page)
            {
                case Page.Welcome:
                    Welcome(g);
                    break;
                case Page.Privacy:
                    Privacy(g);
                    break;
                case Page.Working:
                    Working(g);
                    break;
                case Page.Done:
                case Page.Removed:
                case Page.Failed:
                    Result(g);
                    break;
                case Page.ConfirmRemove:
                    ConfirmRemove(g);
                    break;
            }
            if (page != Page.Working) CloseButton(g);
            // A hairline edge, so a light window stays apart from a light desktop.
            using (var edge = new Pen(Palette.Mix(pal.Surface, pal.Line, 0.9), 1))
            {
                g.DrawRectangle(edge, 0, 0, W * s - 1, H * s - 1);
            }
        }

        void Welcome(Graphics g)
        {
            Logo(g, 52);
            Centered(g, "Sidekick", 30, pal.Text, 156, 42, bold: true);
            Centered(g, "Your phone and computer, working as one.", 15, pal.Muted, 200, 22);
            Centered(
                g,
                installedVersion == null || installedVersion == Payload.Version
                    ? $"Version {Payload.Version}"
                    : $"Updates version {installedVersion} to {Payload.Version}",
                12.5f,
                pal.Muted,
                224,
                18);

            // What it does, in three lines.
            Fill(g, pal.Card, R(40, 262, 340, 118), 16);
            var lines = new[]
            {
                "Send files both ways, phone and PC",
                "Use your phone as touchpad and keyboard",
                "Encrypted, no account, no cloud",
            };
            for (var i = 0; i < lines.Length; i++)
            {
                var y = 276 + i * 32;
                var dot = R(58, y + 2, 22, 22);
                using (var b = new SolidBrush(pal.PrimarySoft)) g.FillEllipse(b, dot);
                Tick(g, dot, pal.OnPrimarySoft, 1.8f);
                Draw(g, lines[i], 14, pal.Text, R(92, y, 280, 26), TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine | TextFormatFlags.EndEllipsis);
            }

            Checkbox(g, "desktop", "Put a shortcut on the desktop", desktop, 42, 398, () =>
            {
                desktop = !desktop;
                Invalidate();
            });
            Draw(g, dir, 12.5f, pal.Muted, R(42, 430, 270, 20), TextFormatFlags.PathEllipsis | TextFormatFlags.SingleLine | TextFormatFlags.VerticalCenter);
            Link(g, "folder", "Change", 12.5f, R(316, 430, 64, 20), TextFormatFlags.Right, PickFolder);

            if (notice != null) Centered(g, notice, 12.5f, pal.Danger, 452, 20);
            Button(g, "go", installedVersion == null ? "Install" : "Update", R(40, 476, 340, 48), Go);
            Link(g, "privacy", "Privacy policy", 12.5f, R(40, 530, 340, 20), TextFormatFlags.HorizontalCenter, () => SetPage(Page.Privacy));
        }

        void Privacy(Graphics g)
        {
            Centered(g, "Privacy policy", 20, pal.Text, 26, 32, bold: true);
            var box = R(40, 72, 340, 388);
            Fill(g, pal.Card, box, 16);
            var inner = Rectangle.Round(new RectangleF(box.X + 18 * s, box.Y + 14 * s, box.Width - 36 * s, box.Height - 28 * s));
            var flags = TextFormatFlags.WordBreak | TextFormatFlags.TextBoxControl | TextFormatFlags.NoPrefix;
            var font = F(13);
            var height = TextRenderer.MeasureText(g, privacy, font, new Size(inner.Width, int.MaxValue), flags).Height;
            scroll = Math.Min(scroll, Math.Max(0, height - inner.Height));
            var clip = g.Clip;
            g.SetClip(inner);
            TextRenderer.DrawText(
                g,
                privacy,
                font,
                new Rectangle(inner.X, inner.Y - scroll, inner.Width, height),
                pal.Text,
                flags | TextFormatFlags.PreserveGraphicsClipping);
            g.Clip = clip;
            if (height > inner.Height)
            {
                // A thin scroll thumb on the right.
                var track = inner.Height;
                var thumb = Math.Max(24 * s, track * (float)inner.Height / height);
                var top = inner.Y + (track - thumb) * scroll / (float)(height - inner.Height);
                Fill(g, Palette.Mix(pal.Card, pal.Muted, 0.45), new RectangleF(box.Right - 9 * s, top, 4 * s, thumb), 2);
            }
            Button(g, "back", "Back", R(40, 476, 340, 48), () => SetPage(Page.Welcome), primary: false);
        }

        void Working(Graphics g)
        {
            Logo(g, 116);
            var title = removing ? "Removing Sidekick…" : installedVersion == null ? "Installing Sidekick…" : "Updating Sidekick…";
            Centered(g, title, 21, pal.Text, 236, 32, bold: true);
            Centered(g, step, 13.5f, pal.Muted, 272, 22);
            var bar = R(70, 318, 280, 8);
            Fill(g, pal.Line, bar, 4);
            var done = (float)Math.Max(0, Math.Min(1, shown));
            if (done > 0.01) Fill(g, pal.Primary, new RectangleF(bar.X, bar.Y, Math.Max(bar.Height, bar.Width * done), bar.Height), 4);
        }

        void Result(Graphics g)
        {
            var failed = page == Page.Failed;
            Logo(g, 104);
            // A check (or "!") popping in on the logo's corner.
            var t = Math.Min(1, (DateTime.Now - pageSince).TotalMilliseconds / 420);
            var pop = (float)(1 + 2.2 * Math.Pow(t - 1, 3) + 1.2 * Math.Pow(t - 1, 2));
            if (t > 0)
            {
                var size = 34 * pop;
                var badge = R(162 + 96 - 24 - (size - 34) / 2, 104 + 96 - 24 - (size - 34) / 2, size, size);
                using (var ring = new SolidBrush(pal.Surface)) g.FillEllipse(ring, Grow(badge, 3 * s));
                using (var b = new SolidBrush(failed ? pal.Danger : pal.Success)) g.FillEllipse(b, badge);
                if (failed)
                {
                    Draw(g, "!", 20 * pop, Color.White, Rectangle.Round(badge), TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine, bold: true);
                }
                else
                {
                    Tick(g, badge, Color.White, 2.6f);
                }
            }

            string title, message;
            if (failed)
            {
                title = removing ? "Couldn't remove Sidekick" : "Couldn't install Sidekick";
                message = error ?? "Something went wrong.";
            }
            else if (removing)
            {
                title = "Sidekick was removed";
                message = "Files you received stay where they are. Thanks for trying Sidekick.";
            }
            else
            {
                title = installedVersion == null ? "Sidekick is ready" : "Sidekick is up to date";
                message = "Find it in the Start menu. It starts with Windows and waits in the tray, next to the clock.";
            }
            Centered(g, title, 22, pal.Text, 228, 34, bold: true);
            Draw(g, message, 14, pal.Muted, R(46, 270, 328, 96), TextFormatFlags.WordBreak | TextFormatFlags.HorizontalCenter | TextFormatFlags.NoPrefix);
            if (failed) Centered(g, "Details: " + Log.Path, 11.5f, pal.Muted, 400, 18);

            if (failed)
            {
                Button(g, "go", "Try again", R(40, 450, 340, 48), Primary);
                Link(g, "close", "Close", 13, R(40, 508, 340, 22), TextFormatFlags.HorizontalCenter, Close);
            }
            else if (removing)
            {
                Button(g, "go", "Close", R(40, 476, 340, 48), Close);
            }
            else
            {
                Button(g, "go", "Open Sidekick", R(40, 450, 340, 48), OpenSidekick);
                Link(g, "close", "Close", 13, R(40, 508, 340, 22), TextFormatFlags.HorizontalCenter, Close);
            }
        }

        void ConfirmRemove(Graphics g)
        {
            Logo(g, 96);
            Centered(g, "Remove Sidekick?", 24, pal.Text, 216, 36, bold: true);
            Draw(
                g,
                "Sidekick, its shortcuts and its firewall rules go. Files you received stay where they are.",
                14,
                pal.Muted,
                R(46, 262, 328, 64),
                TextFormatFlags.WordBreak | TextFormatFlags.HorizontalCenter);
            if (notice != null) Centered(g, notice, 12.5f, pal.Danger, 420, 20);
            Button(g, "go", "Remove", R(40, 450, 340, 48), Go);
            Link(g, "close", "Keep Sidekick", 13, R(40, 508, 340, 22), TextFormatFlags.HorizontalCenter, Close);
        }

        // ------------------------------------------------------------ pieces

        RectangleF R(float x, float y, float w, float h) => new RectangleF(x * s, y * s, w * s, h * s);

        static RectangleF Grow(RectangleF r, float by) => new RectangleF(r.X - by, r.Y - by, r.Width + 2 * by, r.Height + 2 * by);

        Font F(float px, bool bold = false)
        {
            var key = (px * s, bold);
            if (!fonts.TryGetValue(key, out var font))
            {
                font = new Font(bold ? "Segoe UI Semibold" : "Segoe UI", px * s, FontStyle.Regular, GraphicsUnit.Pixel);
                fonts[key] = font;
            }
            return font;
        }

        void Draw(Graphics g, string text, float px, Color color, RectangleF rect, TextFormatFlags flags, bool bold = false) =>
            Draw(g, text, px, color, Rectangle.Round(rect), flags, bold);

        void Draw(Graphics g, string text, float px, Color color, Rectangle rect, TextFormatFlags flags, bool bold = false)
        {
            TextRenderer.DrawText(g, text, F(px, bold), rect, color, flags | TextFormatFlags.NoPadding);
        }

        void Centered(Graphics g, string text, float px, Color color, float y, float h, bool bold = false) =>
            Draw(g, text, px, color, R(24, y, W - 48, h), TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine | TextFormatFlags.EndEllipsis, bold);

        void Logo(Graphics g, float y) => g.DrawImage(logo, R((W - 96) / 2, y, 96, 96));

        static GraphicsPath Rounded(RectangleF r, float radius)
        {
            var d = Math.Min(radius * 2, Math.Min(r.Width, r.Height));
            var path = new GraphicsPath();
            path.AddArc(r.X, r.Y, d, d, 180, 90);
            path.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            path.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
            path.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            path.CloseFigure();
            return path;
        }

        void Fill(Graphics g, Color color, RectangleF r, float radius)
        {
            using (var path = Rounded(r, radius * s))
            using (var brush = new SolidBrush(color))
            {
                g.FillPath(brush, path);
            }
        }

        /// <summary>A check mark inside [r].</summary>
        void Tick(Graphics g, RectangleF r, Color color, float width)
        {
            using (var pen = new Pen(color, width * s) { StartCap = LineCap.Round, EndCap = LineCap.Round, LineJoin = LineJoin.Round })
            {
                g.DrawLines(pen, new[]
                {
                    new PointF(r.X + r.Width * 0.29f, r.Y + r.Height * 0.52f),
                    new PointF(r.X + r.Width * 0.44f, r.Y + r.Height * 0.66f),
                    new PointF(r.X + r.Width * 0.71f, r.Y + r.Height * 0.37f),
                });
            }
        }

        void Button(Graphics g, string id, string label, RectangleF r, Action click, bool primary = true)
        {
            hits.Add((r, id, click));
            var fill = primary ? pal.Primary : pal.Card;
            var text = primary ? pal.OnPrimary : pal.Text;
            if (hover == id) fill = Palette.Mix(fill, pal.Text, pal == Palette.Dark ? 0.12 : 0.08);
            if (hover == id && pressed == id) fill = Palette.Mix(fill, pal.Text, 0.16);
            Fill(g, fill, r, r.Height / s / 2);
            Draw(g, label, 15, text, r, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine, bold: true);
        }

        void Link(Graphics g, string id, string label, float px, RectangleF area, TextFormatFlags align, Action click)
        {
            var size = TextRenderer.MeasureText(g, label, F(px), Size.Empty, TextFormatFlags.NoPadding | TextFormatFlags.SingleLine);
            float x = (align & TextFormatFlags.HorizontalCenter) != 0
                ? area.X + (area.Width - size.Width) / 2
                : (align & TextFormatFlags.Right) != 0 ? area.Right - size.Width : area.X;
            var rect = new RectangleF(x, area.Y + (area.Height - size.Height) / 2, size.Width, size.Height);
            // A little bigger to hit than to see.
            hits.Add((Grow(rect, 6 * s), id, click));
            var color = id == "privacy" || id == "close" ? pal.Muted : pal.Primary;
            if (hover == id) color = pal.Primary;
            Draw(g, label, px, color, rect, TextFormatFlags.SingleLine);
            if (hover == id)
            {
                using (var pen = new Pen(color, Math.Max(1, s)))
                {
                    g.DrawLine(pen, rect.X, rect.Bottom + s, rect.Right, rect.Bottom + s);
                }
            }
        }

        void Checkbox(Graphics g, string id, string label, bool on, float x, float y, Action toggle)
        {
            var box = R(x, y, 20, 20);
            var size = TextRenderer.MeasureText(g, label, F(14), Size.Empty, TextFormatFlags.NoPadding | TextFormatFlags.SingleLine);
            hits.Add((Grow(new RectangleF(box.X, box.Y, box.Width + 12 * s + size.Width, box.Height), 4 * s), id, toggle));
            if (on)
            {
                Fill(g, pal.Primary, box, 6);
                Tick(g, box, pal.OnPrimary, 2.2f);
            }
            else
            {
                using (var path = Rounded(Grow(box, -0.75f * s), 6 * s))
                using (var pen = new Pen(hover == id ? pal.Primary : Palette.Mix(pal.Muted, pal.Surface, 0.3), 1.5f * s))
                {
                    g.DrawPath(pen, path);
                }
            }
            Draw(g, label, 14, pal.Text, new RectangleF(box.Right + 12 * s, box.Y, size.Width + 4 * s, box.Height), TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine);
        }

        void CloseButton(Graphics g)
        {
            var r = R(W - 46, 10, 34, 34);
            hits.Add((r, "x", Close));
            if (hover == "x")
            {
                using (var b = new SolidBrush(pal.Card)) g.FillEllipse(b, r);
            }
            using (var pen = new Pen(pal.Muted, 1.6f * s) { StartCap = LineCap.Round, EndCap = LineCap.Round })
            {
                var c = new PointF(r.X + r.Width / 2, r.Y + r.Height / 2);
                var d = 6 * s;
                g.DrawLine(pen, c.X - d, c.Y - d, c.X + d, c.Y + d);
                g.DrawLine(pen, c.X - d, c.Y + d, c.X + d, c.Y - d);
            }
        }

        [DllImport("dwmapi.dll")]
        static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);

        [DllImport("user32.dll")]
        static extern bool ReleaseCapture();

        [DllImport("user32.dll")]
        static extern IntPtr SendMessage(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam);
    }
}
