using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Text;
using System.Threading;

namespace SidekickSetup
{
    /// <summary>
    /// Start menu and desktop shortcuts. The Start menu one carries
    /// Sidekick's AppUserModelID: Windows shows toasts (phone notifications
    /// on the PC) only for apps with a shortcut that has one.
    /// </summary>
    static class Shortcuts
    {
        public static void Create(string path, string target, string aumid) => OnSta(() =>
        {
            var link = (IShellLinkW)new CShellLink();
            try
            {
                link.SetPath(target);
                link.SetWorkingDirectory(Path.GetDirectoryName(target));
                link.SetIconLocation(target, 0);
                link.SetDescription("Your phone and computer, working as one");
                if (aumid != null)
                {
                    var store = (IPropertyStore)link;
                    var key = AppUserModelId;
                    var value = new PropVariant { vt = VtLpwstr, pointer = Marshal.StringToCoTaskMemUni(aumid) };
                    try
                    {
                        store.SetValue(ref key, ref value);
                        store.Commit();
                    }
                    finally
                    {
                        Marshal.FreeCoTaskMem(value.pointer);
                    }
                }
                Directory.CreateDirectory(Path.GetDirectoryName(path));
                ((IPersistFile)link).Save(path, true);
            }
            finally
            {
                Marshal.ReleaseComObject(link);
            }
        });

        /// <summary>The AppUserModelID a shortcut carries (for CI's check).</summary>
        public static string ReadAumid(string path)
        {
            string result = null;
            OnSta(() =>
            {
                var link = (IShellLinkW)new CShellLink();
                try
                {
                    ((IPersistFile)link).Load(path, 0);
                    var store = (IPropertyStore)link;
                    var key = AppUserModelId;
                    store.GetValue(ref key, out var value);
                    if (value.vt == VtLpwstr) result = Marshal.PtrToStringUni(value.pointer);
                    PropVariantClear(ref value);
                }
                finally
                {
                    Marshal.ReleaseComObject(link);
                }
            });
            return result;
        }

        /// <summary>The shell's COM objects want a single-threaded apartment.</summary>
        static void OnSta(Action action)
        {
            if (Thread.CurrentThread.GetApartmentState() == ApartmentState.STA)
            {
                action();
                return;
            }
            Exception failure = null;
            var thread = new Thread(() =>
            {
                try
                {
                    action();
                }
                catch (Exception e)
                {
                    failure = e;
                }
            });
            thread.SetApartmentState(ApartmentState.STA);
            thread.Start();
            thread.Join();
            if (failure != null) throw failure;
        }

        const ushort VtLpwstr = 31;

        static PropertyKey AppUserModelId => new PropertyKey
        {
            fmtid = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"),
            pid = 5,
        };

        [StructLayout(LayoutKind.Sequential, Pack = 4)]
        struct PropertyKey
        {
            public Guid fmtid;
            public uint pid;
        }

        /// <summary>PROPVARIANT, enough of it for a string.</summary>
        [StructLayout(LayoutKind.Sequential)]
        struct PropVariant
        {
            public ushort vt;
            public ushort reserved1;
            public ushort reserved2;
            public ushort reserved3;
            public IntPtr pointer;
            public IntPtr extra;
        }

        [DllImport("ole32.dll")]
        static extern int PropVariantClear(ref PropVariant pvar);

        [ComImport, Guid("00021401-0000-0000-C000-000000000046")]
        class CShellLink
        {
        }

        [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("000214F9-0000-0000-C000-000000000046")]
        interface IShellLinkW
        {
            void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder file, int max, IntPtr findData, int flags);
            void GetIDList(out IntPtr idList);
            void SetIDList(IntPtr idList);
            void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder name, int max);
            void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string name);
            void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder dir, int max);
            void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string dir);
            void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder args, int max);
            void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string args);
            void GetHotkey(out short hotkey);
            void SetHotkey(short hotkey);
            void GetShowCmd(out int showCmd);
            void SetShowCmd(int showCmd);
            void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder path, int max, out int index);
            void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string path, int index);
            void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string path, int reserved);
            void Resolve(IntPtr hwnd, int flags);
            void SetPath([MarshalAs(UnmanagedType.LPWStr)] string file);
        }

        [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99")]
        interface IPropertyStore
        {
            void GetCount(out uint count);
            void GetAt(uint index, out PropertyKey key);
            void GetValue(ref PropertyKey key, out PropVariant value);
            void SetValue(ref PropertyKey key, ref PropVariant value);
            void Commit();
        }
    }
}
