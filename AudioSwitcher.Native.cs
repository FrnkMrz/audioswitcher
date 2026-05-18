using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using System.Windows.Forms;

namespace PortableAudioSwitcher
{
    public sealed class SwitchEventArgs : EventArgs
    {
        public string Message { get; private set; }
        public SwitchEventArgs(string message) { Message = message; }
    }

    public sealed class HotkeyWindow : NativeWindow, IDisposable
    {
        private const int WM_HOTKEY = 0x0312;
        private const uint MOD_NOREPEAT = 0x4000;
        private readonly int id;
        private readonly AudioDeviceKind deviceKind;
        private bool disposed;

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

        public event EventHandler<SwitchEventArgs> Switched;

        public HotkeyWindow(int id, uint modifiers, uint key, AudioDeviceKind deviceKind)
        {
            this.id = id;
            this.deviceKind = deviceKind;
            CreateHandle(new CreateParams());

            if (!RegisterHotKey(Handle, id, modifiers | MOD_NOREPEAT, key))
            {
                int error = Marshal.GetLastWin32Error();
                DestroyHandle();
                throw new InvalidOperationException("Hotkey konnte nicht registriert werden. Windows-Fehlercode: " + error);
            }
        }

        protected override void WndProc(ref Message m)
        {
            if (m.Msg == WM_HOTKEY && m.WParam.ToInt32() == id)
            {
                string message;
                try
                {
                    if (deviceKind == AudioDeviceKind.Input)
                    {
                        message = AudioSwitcher.SwitchInputToNext(AudioSwitcherSettings.ExcludedInputDeviceNamePatterns);
                    }
                    else
                    {
                        message = AudioSwitcher.SwitchOutputToNext(AudioSwitcherSettings.ExcludedOutputDeviceNamePatterns);
                    }
                }
                catch (Exception ex)
                {
                    message = GetFailurePrefix() + ex.Message;
                }

                EventHandler<SwitchEventArgs> handler = Switched;
                if (handler != null) handler(this, new SwitchEventArgs(message));
            }

            base.WndProc(ref m);
        }

        public void Dispose()
        {
            if (disposed) return;
            disposed = true;
            UnregisterHotKey(Handle, id);
            DestroyHandle();
        }

        private string GetFailurePrefix()
        {
            return deviceKind == AudioDeviceKind.Input
                ? "Mikrofon-Wechsel fehlgeschlagen: "
                : "Audioausgabe-Wechsel fehlgeschlagen: ";
        }
    }

    public static class AudioSwitcher
    {
        private const uint DEVICE_STATE_ACTIVE = 0x00000001;
        private static readonly PROPERTYKEY PKEY_Device_FriendlyName =
            new PROPERTYKEY(new Guid("a45c254e-df1c-4efd-8020-67d146a850e0"), 14);

        public static string SwitchOutputToNext(string[] excludedDeviceNamePatterns)
        {
            return SwitchToNext(
                EDataFlow.eRender,
                excludedDeviceNamePatterns,
                "Keine aktiven Ausgabegeraete gefunden.",
                "Keine aktiven Ausgabegeraete nach Anwendung der Ausschlussliste gefunden.",
                "Audioausgabe");
        }

        public static string SwitchInputToNext(string[] excludedDeviceNamePatterns)
        {
            return SwitchToNext(
                EDataFlow.eCapture,
                excludedDeviceNamePatterns,
                "Keine aktiven Mikrofone gefunden.",
                "Keine aktiven Mikrofone nach Anwendung der Ausschlussliste gefunden.",
                "Mikrofon");
        }

        public static string[] ListOutputDevices()
        {
            return ListActiveDeviceNames(EDataFlow.eRender);
        }

        public static string[] ListInputDevices()
        {
            return ListActiveDeviceNames(EDataFlow.eCapture);
        }

        private static string SwitchToNext(
            EDataFlow dataFlow,
            string[] excludedDeviceNamePatterns,
            string noDevicesMessage,
            string noDevicesAfterExclusionsMessage,
            string messagePrefix)
        {
            IMMDeviceEnumerator enumerator = null;
            IMMDeviceCollection collection = null;
            IMMDevice defaultDevice = null;
            IPolicyConfig policyConfig = null;

            try
            {
                enumerator = (IMMDeviceEnumerator)(new MMDeviceEnumerator());
                enumerator.EnumAudioEndpoints(dataFlow, DEVICE_STATE_ACTIVE, out collection);

                uint count;
                collection.GetCount(out count);
                if (count == 0) throw new InvalidOperationException(noDevicesMessage);

                enumerator.GetDefaultAudioEndpoint(dataFlow, ERole.eConsole, out defaultDevice);
                string defaultId;
                defaultDevice.GetId(out defaultId);

                List<AudioDevice> devices = new List<AudioDevice>();
                int currentIndex = -1;

                for (uint i = 0; i < count; i++)
                {
                    IMMDevice device = null;
                    try
                    {
                        collection.Item(i, out device);
                        string id;
                        device.GetId(out id);
                        string name = GetFriendlyName(device);
                        if (!IsExcluded(name, excludedDeviceNamePatterns))
                        {
                            devices.Add(new AudioDevice(id, name));

                            if (String.Equals(id, defaultId, StringComparison.OrdinalIgnoreCase))
                            {
                                currentIndex = devices.Count - 1;
                            }
                        }
                    }
                    finally
                    {
                        ReleaseComObject(device);
                    }
                }

                if (devices.Count == 0)
                {
                    throw new InvalidOperationException(noDevicesAfterExclusionsMessage);
                }

                int nextIndex = currentIndex < 0 ? 0 : (currentIndex + 1) % devices.Count;
                AudioDevice next = devices[nextIndex];

                policyConfig = (IPolicyConfig)(new CPolicyConfigClient());
                ThrowIfFailed(policyConfig.SetDefaultEndpoint(next.Id, ERole.eConsole), "eConsole");
                ThrowIfFailed(policyConfig.SetDefaultEndpoint(next.Id, ERole.eMultimedia), "eMultimedia");
                ThrowIfFailed(policyConfig.SetDefaultEndpoint(next.Id, ERole.eCommunications), "eCommunications");

                return messagePrefix + ": " + next.Name;
            }
            finally
            {
                ReleaseComObject(policyConfig);
                ReleaseComObject(defaultDevice);
                ReleaseComObject(collection);
                ReleaseComObject(enumerator);
            }
        }

        private static string[] ListActiveDeviceNames(EDataFlow dataFlow)
        {
            IMMDeviceEnumerator enumerator = null;
            IMMDeviceCollection collection = null;
            List<string> devices = new List<string>();

            try
            {
                enumerator = (IMMDeviceEnumerator)(new MMDeviceEnumerator());
                enumerator.EnumAudioEndpoints(dataFlow, DEVICE_STATE_ACTIVE, out collection);

                uint count;
                collection.GetCount(out count);

                for (uint i = 0; i < count; i++)
                {
                    IMMDevice device = null;
                    try
                    {
                        collection.Item(i, out device);
                        devices.Add(GetFriendlyName(device));
                    }
                    finally
                    {
                        ReleaseComObject(device);
                    }
                }

                return devices.ToArray();
            }
            finally
            {
                ReleaseComObject(collection);
                ReleaseComObject(enumerator);
            }
        }

        private static void ThrowIfFailed(int hresult, string role)
        {
            if (hresult < 0)
            {
                Exception error = Marshal.GetExceptionForHR(hresult);
                string detail = error == null ? "HRESULT 0x" + hresult.ToString("X8") : error.Message;
                throw new InvalidOperationException("Standard-Audiogeraet konnte fuer Rolle '" + role + "' nicht gesetzt werden: " + detail);
            }
        }

        private static bool IsExcluded(string deviceName, string[] excludedDeviceNamePatterns)
        {
            if (excludedDeviceNamePatterns == null || excludedDeviceNamePatterns.Length == 0) return false;

            foreach (string pattern in excludedDeviceNamePatterns)
            {
                if (String.IsNullOrWhiteSpace(pattern)) continue;

                string regexPattern = "^" + Regex.Escape(pattern.Trim()).Replace("\\*", ".*").Replace("\\?", ".") + "$";
                if (Regex.IsMatch(deviceName ?? String.Empty, regexPattern, RegexOptions.IgnoreCase))
                {
                    return true;
                }
            }

            return false;
        }

        private static string GetFriendlyName(IMMDevice device)
        {
            IPropertyStore store = null;
            PROPVARIANT value = new PROPVARIANT();
            try
            {
                device.OpenPropertyStore(0, out store);
                PROPERTYKEY friendlyNameKey = PKEY_Device_FriendlyName;
                store.GetValue(ref friendlyNameKey, out value);
                string name = value.GetString();
                return String.IsNullOrWhiteSpace(name) ? "Unbenanntes Audiogeraet" : name;
            }
            finally
            {
                PropVariantClear(ref value);
                ReleaseComObject(store);
            }
        }

        private static void ReleaseComObject(object instance)
        {
            if (instance != null && Marshal.IsComObject(instance))
            {
                try
                {
                    // CoreAudio objects are native COM references. Releasing
                    // them explicitly avoids waiting for the .NET garbage
                    // collector to clean up Windows audio handles later.
                    Marshal.FinalReleaseComObject(instance);
                }
                catch (InvalidComObjectException)
                {
                }
            }
        }

        [DllImport("ole32.dll")]
        private static extern int PropVariantClear(ref PROPVARIANT pvar);
    }

    internal sealed class AudioDevice
    {
        public string Id { get; private set; }
        public string Name { get; private set; }
        public AudioDevice(string id, string name)
        {
            Id = id;
            Name = name;
        }
    }

    public static class AudioSwitcherSettings
    {
        public static string[] ExcludedOutputDeviceNamePatterns = new string[0];
        public static string[] ExcludedInputDeviceNamePatterns = new string[0];
    }

    public enum AudioDeviceKind
    {
        Output = 0,
        Input = 1
    }

    internal enum EDataFlow
    {
        eRender = 0,
        eCapture = 1,
        eAll = 2
    }

    internal enum ERole
    {
        eConsole = 0,
        eMultimedia = 1,
        eCommunications = 2
    }

    // MMDeviceEnumerator is the documented CoreAudio COM object Windows uses
    // to list playback and recording devices.
    [ComImport]
    [Guid("bcde0395-e52f-467c-8e3d-c4579291692e")]
    internal class MMDeviceEnumerator { }

    // IMMDeviceEnumerator is the interface behind MMDeviceEnumerator. The GUID
    // tells .NET which native Windows interface layout to call.
    [ComImport]
    [Guid("a95664d2-9614-4f35-a746-de8db63617e6")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMMDeviceEnumerator
    {
        void EnumAudioEndpoints(EDataFlow dataFlow, uint dwStateMask, out IMMDeviceCollection ppDevices);
        void GetDefaultAudioEndpoint(EDataFlow dataFlow, ERole role, out IMMDevice ppEndpoint);
        void GetDevice([MarshalAs(UnmanagedType.LPWStr)] string pwstrId, out IMMDevice ppDevice);
        void RegisterEndpointNotificationCallback(IntPtr pClient);
        void UnregisterEndpointNotificationCallback(IntPtr pClient);
    }

    [ComImport]
    [Guid("0bd7a1be-7a1a-44db-8397-cc5392387b5e")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMMDeviceCollection
    {
        void GetCount(out uint pcDevices);
        void Item(uint nDevice, out IMMDevice ppDevice);
    }

    [ComImport]
    [Guid("d666063f-1587-4e43-81f1-b948e807363f")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMMDevice
    {
        void Activate(ref Guid iid, uint dwClsCtx, IntPtr pActivationParams, [MarshalAs(UnmanagedType.IUnknown)] out object ppInterface);
        void OpenPropertyStore(uint stgmAccess, out IPropertyStore ppProperties);
        void GetId([MarshalAs(UnmanagedType.LPWStr)] out string ppstrId);
        void GetState(out uint pdwState);
    }

    [ComImport]
    [Guid("886d8eeb-8cf2-4446-8d02-cdba1dbdcf99")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IPropertyStore
    {
        void GetCount(out uint cProps);
        void GetAt(uint iProp, out PROPERTYKEY pkey);
        void GetValue(ref PROPERTYKEY key, out PROPVARIANT pv);
        void SetValue(ref PROPERTYKEY key, ref PROPVARIANT propvar);
        void Commit();
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct PROPERTYKEY
    {
        public Guid fmtid;
        public uint pid;

        public PROPERTYKEY(Guid fmtid, uint pid)
        {
            this.fmtid = fmtid;
            this.pid = pid;
        }
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct PROPVARIANT
    {
        public ushort vt;
        public ushort wReserved1;
        public ushort wReserved2;
        public ushort wReserved3;
        public IntPtr p;
        public int p2;

        public string GetString()
        {
            return vt == 31 && p != IntPtr.Zero ? Marshal.PtrToStringUni(p) : null;
        }
    }

    // IPolicyConfig is an undocumented Windows COM interface. It is stable on
    // Windows 10/11 today, but this block is the likely breaking point if a
    // future Windows release changes the internal CoreAudio policy API. It is
    // what lets this tool change the default audio device without admin rights.
    [ComImport]
    [Guid("870af99c-171d-4f9e-af0d-e63df40c2bc9")]
    internal class CPolicyConfigClient { }

    // This interface exposes Windows' internal audio-policy methods. The GUID
    // identifies the COM interface; method order matters for COM interop.
    [ComImport]
    [Guid("f8679f50-850a-41cf-9c72-430f290290c8")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IPolicyConfig
    {
        [PreserveSig] int GetMixFormat([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, IntPtr ppFormat);
        [PreserveSig] int GetDeviceFormat([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, bool bDefault, IntPtr ppFormat);
        [PreserveSig] int ResetDeviceFormat([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName);
        [PreserveSig] int SetDeviceFormat([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, IntPtr pEndpointFormat, IntPtr mixFormat);
        [PreserveSig] int GetProcessingPeriod([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, bool bDefault, IntPtr pmftDefaultPeriod, IntPtr pmftMinimumPeriod);
        [PreserveSig] int SetProcessingPeriod([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, IntPtr pmftPeriod);
        [PreserveSig] int GetShareMode([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, IntPtr pMode);
        [PreserveSig] int SetShareMode([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, IntPtr mode);
        [PreserveSig] int GetPropertyValue([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, ref PROPERTYKEY key, IntPtr pv);
        [PreserveSig] int SetPropertyValue([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, ref PROPERTYKEY key, ref PROPVARIANT pv);
        // Sets the default endpoint for one Windows audio role, for example
        // normal app audio, multimedia, or communication apps.
        [PreserveSig] int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, ERole role);
        [PreserveSig] int SetEndpointVisibility([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, bool bVisible);
    }
}
