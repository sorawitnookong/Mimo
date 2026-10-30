// Mimo UI. The host (app/Mimo.cs) sends state as JSON and receives small commands.
// Opened in a plain browser, a stand-in host lets the screens be previewed with ?state=mirroring.

const host = window.chrome && window.chrome.webview;

const copy = {
  stopped: {
    tone: "off", status: "Not ready", pill: "Offline", action: "Connect",
    title: "Hello there!", text: "Connect when you are ready to see your phone.",
    device: "No phone connected", detail: "Press Connect, then choose Mimo on your iPhone.",
    mirror: "Press Connect to get started.", previewTitle: "Not connected", previewText: "Your phone screen will show up here.",
  },
  waiting: {
    tone: "ready", status: "Waiting for phone", pill: "Waiting", action: "Stop",
    title: "Ready when you are", text: "Mimo is waiting for your iPhone.",
    device: "Waiting for your phone", detail: "The first start can take a few minutes.",
    mirror: "Waiting for your iPhone to connect.", previewTitle: "Waiting…", previewText: "Open Screen Mirroring on your iPhone.",
  },
  connecting: {
    tone: "busy", status: "Connecting", pill: "Connecting", action: "Stop",
    title: "Saying hello…", text: "Your phone is connecting to Mimo.",
    mirror: "Connecting to your phone.", previewTitle: "Connecting…", previewText: "This only takes a moment.",
  },
  mirroring: {
    tone: "live", status: "Mirroring", pill: "Connected", action: "Disconnect",
    title: "Your phone is here", text: "Mirroring is running in the Mimo video window.",
    mirror: "Your phone is showing in the Mimo video window.", previewTitle: "Mirroring", previewText: "Use Show mirror to bring it to the front.",
  },
  error: {
    tone: "alert", status: "Needs attention", pill: "Stopped", action: "Try again",
    title: "Something went wrong", text: "Mimo stopped receiving.",
    device: "No phone connected", detail: "Press Try again to restart.",
    mirror: "Mimo stopped receiving.", previewTitle: "Disconnected", previewText: "Press Try again to restart.",
  },
};

let current = null;
let selectedDevice = null;
let formLoaded = false;

const all = (selector) => document.querySelectorAll(selector);
const setText = (selector, text) => all(selector).forEach((node) => { node.textContent = text; });

function send(message) {
  if (host) {
    host.postMessage(message);
  } else {
    previewHost(message);
  }
}

function showView(name) {
  all(".view").forEach((view) => { view.hidden = view.id !== name; });
  all(".nav-item").forEach((item) => {
    if (item.dataset.view === name) {
      item.setAttribute("aria-current", "page");
    } else {
      item.removeAttribute("aria-current");
    }
  });
}

function render(next) {
  current = next;
  const text = copy[next.state];
  const device = next.device;

  setText("[data-status-text]", text.status);
  setText("[data-status-pill]", text.pill);
  all("[data-status-dot], [data-status-pill], [data-phone-mark], [data-preview]").forEach((node) => {
    node.dataset.tone = text.tone;
  });
  setText("[data-hero-title]", text.title);
  setText("[data-hero-text]", text.text);
  setText("[data-device-name]", device ? device.name : text.device);
  setText("[data-device-detail]", device ? device.model : text.detail);
  setText("[data-mirror-text]", text.mirror);
  setText("[data-preview-title]", text.previewTitle);
  setText("[data-preview-text]", text.previewText);
  setText("[data-video-size]", next.videoSize);
  setText("[data-server-name]", next.settings.serverName);

  all('[data-action="toggle"]').forEach((button) => {
    button.textContent = text.action;
    button.classList.toggle("secondary-tone", next.state === "mirroring");
  });
  all('[data-action="show"]').forEach((button) => { button.hidden = next.state !== "mirroring"; });
  document.querySelector("[data-steps]").hidden = next.state === "mirroring" || next.state === "connecting";
  document.querySelector("[data-loader]").hidden = next.state !== "connecting" && next.state !== "waiting";
  document.querySelector("[data-preview-icon]").style.display =
    (next.state === "connecting" || next.state === "waiting") ? "none" : "";

  document.querySelector("[data-error]").hidden = !next.error;
  setText("[data-error-text]", next.error || "");

  if (!formLoaded) {
    fillSettings(next.settings);
    formLoaded = true;
  }
  renderDevices();
}

function renderDevices() {
  const devices = current.settings.devices;
  const list = document.querySelector("[data-device-list]");
  const info = document.querySelector("[data-device-info]");
  list.replaceChildren();
  info.replaceChildren();

  if (!devices.length) {
    list.append(emptyState("i-devices", "No phones yet", "Connect your iPhone once and it shows up here."));
    info.append(emptyState("i-phone", "Nothing selected", "Device details appear here."));
    return;
  }

  const selected = devices.find((device) => device.id === selectedDevice) || devices[0];
  devices.forEach((device) => {
    const row = document.createElement("button");
    row.className = "device-row";
    row.setAttribute("aria-pressed", String(device.id === selected.id));
    row.innerHTML = '<svg class="icon"><use href="#i-phone"/></svg><span><strong></strong><small></small></span>';
    row.querySelector("strong").textContent = device.name;
    row.querySelector("small").textContent = isConnected(device) ? "Connected" : device.model;
    row.addEventListener("click", () => {
      selectedDevice = device.id;
      renderDevices();
    });
    list.append(row);
  });

  const title = document.createElement("h2");
  title.textContent = selected.name;
  const details = document.createElement("dl");
  details.className = "info-list";
  [
    ["Status", isConnected(selected) ? "Connected" : "Not connected"],
    ["Model", selected.model],
    ["Last connected", selected.lastSeen],
    ["Device ID", selected.id],
  ].forEach(([label, value]) => {
    const term = document.createElement("dt");
    term.textContent = label;
    const description = document.createElement("dd");
    description.textContent = value;
    description.className = label === "Device ID" ? "technical" : "";
    details.append(term, description);
  });
  info.append(title, details);
}

function isConnected(device) {
  return Boolean(current.device && current.device.id === device.id);
}

function emptyState(icon, title, text) {
  const node = document.createElement("div");
  node.className = "empty";
  node.innerHTML = `<svg class="icon"><use href="#${icon}"/></svg><strong></strong><span></span>`;
  node.querySelector("strong").textContent = title;
  node.querySelector("span").textContent = text;
  return node;
}

function fillSettings(settings) {
  const form = document.querySelector("[data-settings-form]");
  form.serverName.value = settings.serverName;
  form.resolution.value = settings.resolution;
  form.fps.value = String(settings.fps);
  form.audio.checked = settings.audio;
  form.startOnOpen.checked = settings.startOnOpen;
}

document.addEventListener("click", (event) => {
  const nav = event.target.closest("[data-view]");
  if (nav) {
    showView(nav.dataset.view);
    return;
  }
  const action = event.target.closest("[data-action]");
  if (!action) {
    return;
  }
  if (action.dataset.action === "show") {
    send({ type: "showVideo" });
  } else if (current.state === "stopped" || current.state === "error") {
    send({ type: "start" });
  } else {
    send({ type: "stop" });
  }
});

document.querySelector("[data-settings-form]").addEventListener("submit", (event) => {
  event.preventDefault();
  const form = event.target;
  send({
    type: "saveSettings",
    settings: {
      serverName: form.serverName.value.trim() || "Mimo",
      resolution: form.resolution.value,
      fps: Number(form.fps.value),
      audio: form.audio.checked,
      startOnOpen: form.startOnOpen.checked,
    },
  });
  const saved = document.querySelector("[data-saved]");
  saved.hidden = false;
  setTimeout(() => { saved.hidden = true; }, 2000);
});

function previewHost(message) {
  const next = { ...current, error: null, device: null, videoSize: "" };
  if (message.type === "start") {
    next.state = "waiting";
  } else if (message.type === "stop") {
    next.state = "stopped";
  } else if (message.type === "saveSettings") {
    next.settings = { ...current.settings, ...message.settings };
  } else {
    return;
  }
  render(next);
}

if (host) {
  host.addEventListener("message", (event) => render(event.data));
} else {
  const state = new URLSearchParams(location.search).get("state") || "stopped";
  const device = { id: "00:11:22:33:44:55", name: "Mello's iPhone", model: "iPhone15,2", lastSeen: "2026-10-30 22:10" };
  const live = state === "mirroring" || state === "connecting";
  render({
    state,
    error: state === "error" ? "The receiver stopped unexpectedly." : null,
    device: live ? device : null,
    videoSize: state === "mirroring" ? "886 × 1920" : "",
    settings: {
      serverName: "Mimo", resolution: "1920x1080", fps: 60, audio: true, startOnOpen: true,
      devices: live ? [device] : [],
    },
  });
}

showView(new URLSearchParams(location.search).get("view") || "dashboard");
if (host) {
  host.postMessage({ type: "ready" });
}
