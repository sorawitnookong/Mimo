// Mimo desktop app: a WebView2 window that runs uxplay and shows its state.
// The UI lives in app/ui. It talks to this class with small JSON messages.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

namespace Mimo
{
    internal sealed class Settings
    {
        public string serverName = "Mimo";
        public string resolution = "1920x1080";
        public int fps = 60;
        public bool audio = true;
        public bool startOnOpen = true;
        public List<Dictionary<string, object>> devices = new List<Dictionary<string, object>>();
    }

    internal sealed class MainForm : Form
    {
        const string MsysBin = @"C:\msys64\ucrt64\bin";
        const int WM_CLOSE = 0x0010;

        static readonly Regex ConnectionRequest =
            new Regex(@"connection request from (.*) \((.*)\) with deviceID = (\S+)");
        static readonly Regex VideoSize = new Regex(@"fit video window to (\d+)x(\d+) video");
        static readonly Regex OpenConnections = new Regex(@"Open connections: (\d+)");

        readonly WebView2 web = new WebView2();
        readonly JavaScriptSerializer json = new JavaScriptSerializer();
        readonly string root;
        readonly string settingsPath;
        Settings settings;
        Process receiver;
        bool stopping;
        string state = "stopped";
        string videoSize = "";
        Dictionary<string, object> device;

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        static extern IntPtr FindWindow(string className, string title);
        [DllImport("user32.dll")]
        static extern bool SetForegroundWindow(IntPtr hwnd);
        [DllImport("user32.dll")]
        static extern bool ShowWindow(IntPtr hwnd, int command);
        [DllImport("user32.dll")]
        static extern bool PostMessage(IntPtr hwnd, int msg, IntPtr wparam, IntPtr lparam);

        public MainForm()
        {
            root = AppDomain.CurrentDomain.BaseDirectory;
            string data = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Mimo");
            Directory.CreateDirectory(data);
            settingsPath = Path.Combine(data, "settings.json");
            settings = LoadSettings();

            Text = "Mimo";
            ClientSize = new Size(1080, 720);
            MinimumSize = new Size(760, 560);
            StartPosition = FormStartPosition.CenterScreen;
            BackColor = ColorTranslator.FromHtml("#F8FAFF");
            Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
            web.Dock = DockStyle.Fill;
            web.DefaultBackgroundColor = BackColor;
            Controls.Add(web);
            Load += async (sender, args) =>
            {
                try
                {
                    var environment = await CoreWebView2Environment.CreateAsync(null, Path.Combine(data, "webview"));
                    await web.EnsureCoreWebView2Async(environment);
                }
                catch (Exception error)
                {
                    MessageBox.Show("Mimo could not open its window.\n\n" + error.Message, "Mimo");
                    Close();
                    return;
                }
                web.CoreWebView2.Settings.AreDevToolsEnabled = false;
                web.CoreWebView2.Settings.IsStatusBarEnabled = false;
                web.CoreWebView2.Settings.AreDefaultContextMenusEnabled = false;
                web.CoreWebView2.SetVirtualHostNameToFolderMapping("mimo.local",
                    Path.Combine(root, "app", "ui"), CoreWebView2HostResourceAccessKind.Allow);
                web.CoreWebView2.WebMessageReceived += OnWebMessage;
                web.CoreWebView2.Navigate("https://mimo.local/index.html");
            };
            FormClosing += (sender, args) => StopReceiver();
        }

        Settings LoadSettings()
        {
            try
            {
                return json.Deserialize<Settings>(File.ReadAllText(settingsPath)) ?? new Settings();
            }
            catch (Exception)
            {
                return new Settings();
            }
        }

        void SaveSettings()
        {
            File.WriteAllText(settingsPath, json.Serialize(settings));
        }

        void OnWebMessage(object sender, CoreWebView2WebMessageReceivedEventArgs args)
        {
            var message = json.Deserialize<Dictionary<string, object>>(args.WebMessageAsJson);
            switch ((string) message["type"])
            {
                case "ready":
                    SendState();
                    if (settings.startOnOpen) StartReceiver();
                    break;
                case "start":
                    StartReceiver();
                    break;
                case "stop":
                    StopReceiver();
                    break;
                case "showVideo":
                    ShowVideo();
                    break;
                case "saveSettings":
                    ApplySettings((Dictionary<string, object>) message["settings"]);
                    break;
            }
        }

        void ApplySettings(Dictionary<string, object> values)
        {
            settings.serverName = (string) values["serverName"];
            settings.resolution = (string) values["resolution"];
            settings.fps = Convert.ToInt32(values["fps"]);
            settings.audio = (bool) values["audio"];
            settings.startOnOpen = (bool) values["startOnOpen"];
            SaveSettings();
            if (receiver != null)
            {
                StopReceiver();
                StartReceiver();
            }
            else
            {
                SendState();
            }
        }

        string ReceiverArguments()
        {
            string name = settings.serverName.Replace("\"", "");
            var arguments = new StringBuilder();
            arguments.AppendFormat("-n \"{0}\" -nh -vs d3d12videosink ", name);
            arguments.AppendFormat("-s {0}@{1} -fps {1}", settings.resolution, settings.fps);
            if (settings.resolution == "2560x1440") arguments.Append(" -h265");
            if (!settings.audio) arguments.Append(" -a");
            return arguments.ToString();
        }

        void StartReceiver()
        {
            if (receiver != null) return;
            // an installed Mimo carries its receiver; a source checkout uses build-fit and MSYS2
            string installed = Path.Combine(root, "receiver");
            bool packaged = File.Exists(Path.Combine(installed, "bin", "uxplay.exe"));
            string folder = packaged ? Path.Combine(installed, "bin") : Path.Combine(root, "build-fit");
            string libraries = packaged ? folder : MsysBin;
            string exe = Path.Combine(folder, "uxplay.exe");
            if (!File.Exists(exe) || !Directory.Exists(libraries))
            {
                SetState("error", "Mimo could not find its receiver files.");
                return;
            }
            var info = new ProcessStartInfo(exe, ReceiverArguments())
            {
                WorkingDirectory = folder,
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
            };
            info.EnvironmentVariables["PATH"] = libraries + ";" + info.EnvironmentVariables["PATH"];
            if (packaged)
            {
                string data = Path.GetDirectoryName(settingsPath);
                info.EnvironmentVariables["GST_PLUGIN_SYSTEM_PATH_1_0"] = Path.Combine(installed, "lib", "gstreamer-1.0");
                info.EnvironmentVariables["GST_PLUGIN_SCANNER_1_0"] =
                    Path.Combine(installed, "libexec", "gstreamer-1.0", "gst-plugin-scanner.exe");
                info.EnvironmentVariables["GST_REGISTRY_1_0"] = Path.Combine(data, "gstreamer-registry.bin");
            }
            var process = new Process { StartInfo = info, EnableRaisingEvents = true };
            process.OutputDataReceived += (sender, args) => OnLogLine(args.Data);
            process.ErrorDataReceived += (sender, args) => OnLogLine(args.Data);
            process.Exited += (sender, args) => BeginInvoke((Action) (() => OnReceiverExit(process)));
            File.WriteAllText(Path.ChangeExtension(settingsPath, ".log"), "");
            stopping = false;
            device = null;
            videoSize = "";
            receiver = process;
            process.Start();
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();
            SetState("waiting", null);
        }

        void StopReceiver()
        {
            Process process = receiver;
            if (process == null) return;
            stopping = true;
            receiver = null;
            // closing the video window shuts uxplay down normally; it is not there before a device connects
            IntPtr video = FindWindow("MimoVideoWindow", null);
            if (video != IntPtr.Zero) PostMessage(video, WM_CLOSE, IntPtr.Zero, IntPtr.Zero);
            if (!process.WaitForExit(1500))
            {
                try { process.Kill(); } catch (InvalidOperationException) { }
            }
            device = null;
            videoSize = "";
            if (!IsDisposed) SetState("stopped", null);
        }

        void OnReceiverExit(Process process)
        {
            if (process != receiver) return;
            receiver = null;
            device = null;
            videoSize = "";
            if (stopping || process.ExitCode == 0)
            {
                SetState("stopped", null);
            }
            else
            {
                SetState("error", "The receiver stopped unexpectedly.");
            }
        }

        void OnLogLine(string line)
        {
            if (string.IsNullOrEmpty(line) || IsDisposed) return;
            BeginInvoke((Action) (() => HandleLogLine(line)));
        }

        void HandleLogLine(string line)
        {
            File.AppendAllText(Path.ChangeExtension(settingsPath, ".log"), line + Environment.NewLine);
            Match match = ConnectionRequest.Match(line);
            if (match.Success)
            {
                device = RememberDevice(match.Groups[1].Value, match.Groups[2].Value, match.Groups[3].Value);
                SetState("connecting", null);
                return;
            }
            match = VideoSize.Match(line);
            if (match.Success)
            {
                videoSize = match.Groups[1].Value + " × " + match.Groups[2].Value;
                SetState("mirroring", null);
                return;
            }
            if (line.Contains("Begin streaming to GStreamer video pipeline"))
            {
                SetState("mirroring", null);
                return;
            }
            match = OpenConnections.Match(line);
            if (match.Success && match.Groups[1].Value == "0")
            {
                device = null;
                videoSize = "";
                SetState("waiting", null);
            }
        }

        Dictionary<string, object> RememberDevice(string name, string model, string id)
        {
            Dictionary<string, object> entry = settings.devices.Find(item => (string) item["id"] == id);
            if (entry == null)
            {
                entry = new Dictionary<string, object> { { "id", id } };
                settings.devices.Insert(0, entry);
            }
            entry["name"] = name;
            entry["model"] = model;
            entry["lastSeen"] = DateTime.Now.ToString("yyyy-MM-dd HH:mm", CultureInfo.InvariantCulture);
            SaveSettings();
            return entry;
        }

        void ShowVideo()
        {
            IntPtr video = FindWindow("MimoVideoWindow", null);
            if (video == IntPtr.Zero) return;
            ShowWindow(video, 9);
            SetForegroundWindow(video);
        }

        void SetState(string value, string error)
        {
            state = value;
            SendState(error);
        }

        void SendState(string error = null)
        {
            if (web.CoreWebView2 == null) return;
            web.CoreWebView2.PostWebMessageAsJson(json.Serialize(new Dictionary<string, object>
            {
                { "state", state },
                { "error", error },
                { "device", device },
                { "videoSize", videoSize },
                { "settings", settings },
            }));
        }
    }

    internal static class Program
    {
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm());
        }
    }
}
