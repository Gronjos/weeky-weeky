# weeky-weeky
Week Number and Weather Widget for Windows Powershell

# Week + Weather Widget (PowerShell)

Small floating widget showing:
- Week number
- Current temperature
- Weather icon

## Features
- Borderless window
- Semi-transparent
- Draggable
- Snaps to taskbar (right click)
- Updates weather every 10 min

## Screenshot
<img width="301" height="223" alt="image" src="https://github.com/user-attachments/assets/eb370c5e-6fe4-4b3a-b1b7-e6282d545e18" />

## Run
```bash
powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File weeky-weeky.ps1
```

Alternatively you can use the .exe version of the powershell script: weeky-weeky.exe

## Tips
- Create Shortcut and add to you Taskbar or run at startup.
- Adjust location in script with latitude and longitude to get local weather.
