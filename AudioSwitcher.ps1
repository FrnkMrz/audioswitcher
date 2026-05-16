param(
    [string]$Hotkey = "Ctrl+Alt+A",
    [switch]$NoTray
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Resolve-WindowsFormsReferences {
    $references = [System.Collections.Generic.List[string]]::new()
    $references.Add("System.Windows.Forms.dll")

    try {
        $primitives = [System.Reflection.Assembly]::Load("System.Windows.Forms.Primitives")
        if ($primitives.Location) {
            $references.Add($primitives.Location)
        }
    }
    catch {
    }

    $references.ToArray()
}

Add-Type -ReferencedAssemblies (Resolve-WindowsFormsReferences) -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
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
        private readonly int id;
        private bool disposed;

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

        public event EventHandler<SwitchEventArgs> Switched;

        public HotkeyWindow(int id, uint modifiers, uint key)
        {
            this.id = id;
            CreateHandle(new CreateParams());

            if (!RegisterHotKey(Handle, id, modifiers, key))
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
                    message = AudioSwitcher.SwitchToNext();
                }
                catch (Exception ex)
                {
                    message = "Audio-Wechsel fehlgeschlagen: " + ex.Message;
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
    }

    public static class AudioSwitcher
    {
        private const uint DEVICE_STATE_ACTIVE = 0x00000001;
        private static readonly PROPERTYKEY PKEY_Device_FriendlyName =
            new PROPERTYKEY(new Guid("a45c254e-df1c-4efd-8020-67d146a850e0"), 14);

        public static string SwitchToNext()
        {
            IMMDeviceEnumerator enumerator = (IMMDeviceEnumerator)(new MMDeviceEnumerator());
            IMMDeviceCollection collection;
            enumerator.EnumAudioEndpoints(EDataFlow.eRender, DEVICE_STATE_ACTIVE, out collection);

            uint count;
            collection.GetCount(out count);
            if (count == 0) throw new InvalidOperationException("Keine aktiven Ausgabegeraete gefunden.");

            IMMDevice defaultDevice;
            enumerator.GetDefaultAudioEndpoint(EDataFlow.eRender, ERole.eConsole, out defaultDevice);
            string defaultId;
            defaultDevice.GetId(out defaultId);

            List<AudioDevice> devices = new List<AudioDevice>();
            int currentIndex = -1;

            for (uint i = 0; i < count; i++)
            {
                IMMDevice device;
                collection.Item(i, out device);
                string id;
                device.GetId(out id);
                string name = GetFriendlyName(device);
                devices.Add(new AudioDevice(id, name));

                if (String.Equals(id, defaultId, StringComparison.OrdinalIgnoreCase))
                {
                    currentIndex = (int)i;
                }
            }

            int nextIndex = currentIndex < 0 ? 0 : (currentIndex + 1) % devices.Count;
            AudioDevice next = devices[nextIndex];

            IPolicyConfig policyConfig = (IPolicyConfig)(new CPolicyConfigClient());
            ThrowIfFailed(policyConfig.SetDefaultEndpoint(next.Id, ERole.eConsole), "eConsole");
            ThrowIfFailed(policyConfig.SetDefaultEndpoint(next.Id, ERole.eMultimedia), "eMultimedia");
            ThrowIfFailed(policyConfig.SetDefaultEndpoint(next.Id, ERole.eCommunications), "eCommunications");

            return "Audioausgabe: " + next.Name;
        }

        private static void ThrowIfFailed(int hresult, string role)
        {
            if (hresult < 0)
            {
                Marshal.ThrowExceptionForHR(hresult);
            }
        }

        private static string GetFriendlyName(IMMDevice device)
        {
            IPropertyStore store;
            device.OpenPropertyStore(0, out store);
            PROPVARIANT value = new PROPVARIANT();
            try
            {
                store.GetValue(ref PKEY_Device_FriendlyName, out value);
                string name = value.GetString();
                return String.IsNullOrWhiteSpace(name) ? "Unbenanntes Audiogeraet" : name;
            }
            finally
            {
                PropVariantClear(ref value);
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

    [ComImport]
    [Guid("bcde0395-e52f-467c-8e3d-c4579291692e")]
    internal class MMDeviceEnumerator { }

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
    [Guid("0bd7a1be-7a1a-44db-8397-c0bfeaea36bb")]
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

    [ComImport]
    [Guid("870af99c-171d-4f9e-af0d-e63df40c2bc9")]
    internal class CPolicyConfigClient { }

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
        [PreserveSig] int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, ERole role);
        [PreserveSig] int SetEndpointVisibility([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, bool bVisible);
    }
}
"@

function ConvertTo-HotkeyParts {
    param([string]$HotkeyText)

    $parts = $HotkeyText -split "\+" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    if ($parts.Count -lt 1) {
        throw "Hotkey ist leer. Beispiel: Ctrl+Alt+A"
    }

    $modifiers = [uint32]0
    $keyName = $null

    foreach ($part in $parts) {
        switch -Regex ($part) {
            "^(Ctrl|Control|Strg)$" { $modifiers = $modifiers -bor 0x0002; continue }
            "^(Alt)$" { $modifiers = $modifiers -bor 0x0001; continue }
            "^(Shift|Umschalt)$" { $modifiers = $modifiers -bor 0x0004; continue }
            "^(Win|Windows|Meta)$" { $modifiers = $modifiers -bor 0x0008; continue }
            default {
                if ($keyName) {
                    throw "Bitte genau eine normale Taste im Hotkey verwenden. Beispiel: Ctrl+Alt+A"
                }
                $keyName = $part
            }
        }
    }

    if (-not $keyName) {
        throw "Bitte eine normale Taste im Hotkey angeben. Beispiel: Ctrl+Alt+A"
    }

    try {
        $key = [System.Windows.Forms.Keys]::$keyName
    }
    catch {
        throw "Taste '$keyName' wurde nicht erkannt. Beispiele: A, F8, MediaNextTrack"
    }

    if ([int]$key -eq 0) {
        throw "Taste '$keyName' wurde nicht erkannt. Beispiele: A, F8, MediaNextTrack"
    }

    [pscustomobject]@{
        Modifiers = $modifiers
        Key = [uint32][int]$key
    }
}

$hotkeyParts = ConvertTo-HotkeyParts -HotkeyText $Hotkey
$window = [PortableAudioSwitcher.HotkeyWindow]::new(41011, $hotkeyParts.Modifiers, $hotkeyParts.Key)

$tray = $null
if (-not $NoTray) {
    $tray = [System.Windows.Forms.NotifyIcon]::new()
    $tray.Icon = [System.Drawing.SystemIcons]::Application
    $tray.Text = "Audio Switcher ($Hotkey)"
    $tray.Visible = $true

    $menu = [System.Windows.Forms.ContextMenuStrip]::new()
    $quitItem = [System.Windows.Forms.ToolStripMenuItem]::new("Beenden")
    $quitItem.add_Click({
        [System.Windows.Forms.Application]::Exit()
    })
    [void]$menu.Items.Add($quitItem)
    $tray.ContextMenuStrip = $menu
}

$window.add_Switched({
    param($sender, $eventArgs)
    Write-Host $eventArgs.Message
    if ($script:tray) {
        $script:tray.BalloonTipTitle = "Audio Switcher"
        $script:tray.BalloonTipText = $eventArgs.Message
        $script:tray.ShowBalloonTip(1200)
    }
})

try {
    Write-Host "Audio Switcher laeuft. Hotkey: $Hotkey"
    Write-Host "Zum Beenden das Tray-Menue verwenden oder dieses Fenster schliessen."
    [System.Windows.Forms.Application]::Run()
}
finally {
    if ($tray) {
        $tray.Visible = $false
        $tray.Dispose()
    }
    $window.Dispose()
}
