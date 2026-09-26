# n8n Local Triggers Suite Workspace Guidelines

This repository manages local triggers for n8n:
- **Local File Trigger**: Monitored in `./watch_folder`
- **Incoming Webhooks**: Listened on `/webhook/local-api-webhook` and `/webhook-test/local-api-webhook`
- **Schedule & Instance Triggers**: Managed via workflow definitions in `./workflows`
- **Testing**: Executed via `powershell -File .\test-triggers.ps1`
