' Windows Silent Background Launcher for n8n Local Triggers Suite
' Runs n8n completely hidden without popping up a console window

Set WshShell = CreateObject("WScript.Shell")
WshShell.CurrentDirectory = "C:\Users\tee\.gemini\antigravity-ide\scratch\n8n-triggers-suite"
WshShell.Run "cmd.exe /c n8n start", 0, False
