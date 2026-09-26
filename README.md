# n8n Local Triggers & Zero-Click Suite

This repository implements all three local trigger architectures for n8n with a **Zero-Click Authentication Bypass Proxy**:
1. **Zero-Click Authentication Bypass** (Direct access to `http://localhost:5678` with zero credential prompts)
2. **File System Monitoring** (`Local File Trigger`)
3. **Local & External Webhooks** (`Webhook` + `Respond to Webhook` + Tunneling)
4. **Instance & Scheduled Triggers** (`Schedule Trigger` + `n8n Trigger` core node)

---

## Directory Structure

```text
n8n-triggers-suite/
├── docker-compose.yml              # Pre-configured container stack with auth_proxy sidecar
├── start-n8n.ps1                   # Launch n8n locally via npx or Docker with auto-auth
├── test-triggers.ps1               # Automated test script (Auth, File, Webhook, Tunnel)
├── autostart/                      # Silent Windows background startup scripts
│   ├── start-n8n-silent.vbs
│   ├── install-autostart.ps1
│   └── uninstall-autostart.ps1
├── proxy/
│   └── auto-auth-proxy.js          # Zero-dependency auto-login proxy sidecar
├── watch_folder/                   # Monitored directory for file events
│   └── sample_drop.txt
└── workflows/
    ├── all_in_one_triggers_workflow.json      # Master suite with all 3 triggers
    ├── 1_local_file_trigger.json              # Trigger 1: Local file monitoring
    ├── 2_webhook_trigger.json                 # Trigger 2: Incoming webhook receiver
    └── 3_schedule_and_instance_trigger.json   # Trigger 3: Cron & system events
```

---

## 1. Quick Start: Launching n8n with Zero-Click Authentication

Because n8n v1.0+ enforces mandatory authentication and removed `N8N_USER_MANAGEMENT_DISABLED`, this suite includes a transparent **Auto-Auth Proxy** that auto-creates the local admin account and injects the session cookie seamlessly.

### Launch Stack (Fastest via NPX):
```powershell
cd C:\Users\tee\.gemini\antigravity-ide\scratch\n8n-triggers-suite
.\start-n8n.ps1 -Mode npx
```
*Your browser will automatically open to `http://localhost:5678` and land directly on the workflow canvas without any login screen or password prompt.*

### Launch Stack via Docker Compose:
```powershell
docker compose up -d
```
*Both `n8n` and the `auth_proxy` sidecar will spin up together.*

---

## 2. Default Local Developer Credentials

The auto-auth proxy provisions and logs in with the following local defaults (stored only locally):
- **Email:** `admin@local.dev`
- **Password:** `LocalDevPassword123!`

---

## 3. The Triggers

### Trigger 1: File System Monitoring (`Local File Trigger`)
- **Node Used:** `n8n-nodes-base.localFileTrigger`
- **Path:**
  - Host/npx: `C:\Users\tee\.gemini\antigravity-ide\scratch\n8n-triggers-suite\watch_folder` (or `./watch_folder`)
  - Docker: `/data/watch_folder`
- **Options:** `Await Write Finish` & `Use Polling` are enabled for reliable Windows change detection.

### Trigger 2: Incoming Webhooks (Local & Public Tunnel)
- **Nodes Used:** `Webhook` & `Respond to Webhook`
- **Endpoints:**
  - Test: `http://localhost:5678/webhook-test/local-api-webhook`
  - Production: `http://localhost:5678/webhook/local-api-webhook`
- **Public Tunneling:**
  ```powershell
  cloudflared tunnel --url http://localhost:5678
  ```

### Trigger 3: Schedule & Instance Triggers
- **Nodes Used:** `Schedule Trigger` & `n8n Trigger`
- **Events:** Fires on recurring cron interval (every 15 min) and on instance startup (`n8n.ready`).

---

## 4. Automated Testing

Run the included automated verification script:

```powershell
# Test everything (Auth, File, Webhook, Tunnel):
powershell -ExecutionPolicy Bypass -File .\test-triggers.ps1

# Or test a specific component:
.\test-triggers.ps1 -Target auth
.\test-triggers.ps1 -Target file
.\test-triggers.ps1 -Target webhook
.\test-triggers.ps1 -Target tunnel
```

---

## 5. Auto-Start on System Boot (Windows)

To have n8n run silently in the background automatically whenever you log into Windows:

```powershell
# Enable Auto-Start:
powershell -ExecutionPolicy Bypass -File .\autostart\install-autostart.ps1

# Disable Auto-Start:
powershell -ExecutionPolicy Bypass -File .\autostart\uninstall-autostart.ps1
```
*(Uses a silent background VBScript runner with zero popup windows)*
