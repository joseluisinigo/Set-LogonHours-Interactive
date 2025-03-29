# Set-LogonHours-Interactive.ps1

A fully interactive PowerShell script that allows administrators to apply **logon hour restrictions** to users in **Active Directory** based on their **Organizational Unit (OU)**. This tool is especially useful for controlling when users can log in to the domain.

---

## ✨ Features

- 🏢 OU selection from available OUs in Active Directory
- 👤 Apply logon hour restrictions to **one user** or **all users** in the selected OU
- ⏰ Interactive menu to:
  - Add time ranges (days + hours)
  - Remove time ranges
  - Confirm and apply restrictions
- ⏳ Supports **24-hour** and **12-hour AM/PM** input formats
- ✅ Handles single days (e.g., `M`, `F`) and ranges (`M-F`, `Sa-Su`, `F-M`)
- ⚠ Displays warnings for non-supported minute values (AD only supports full hours)
- 🌐 Fully localized to English but usable in Spanish AD environments

---

## 📚 How It Works

Active Directory stores logon hours as a **21-byte array** (7 days * 24 hours = 168 bits):
- Each bit represents **one hour** of the week
- **Sunday is day 0**, **Monday is day 1**, ..., **Saturday is day 6**
- A `1` bit means login is **allowed**, a `0` means login is **denied**
- The end hour is **exclusive**

---

## 🔧 Requirements

- Windows Server with Active Directory
- PowerShell (run as Administrator)
- `ActiveDirectory` module installed (automatically available on AD DS servers)

---

## 📋 Usage

1. Open PowerShell **as Administrator**
2. Run the script:
   ```powershell
   .\Set-LogonHours-Interactive.ps1
   ```
3. Follow the interactive prompts:
   - Choose an OU
   - Select one user or all users
   - Add time ranges like:
     - Days: `M-F`, `Sa`, `F-M`
     - Times: `16:00` to `21:00`, or `4PM` to `9PM`
   - Save and apply

---

## 🔸 Time Format Examples

| Input       | Format    | Notes                         |
|-------------|-----------|-------------------------------|
| `16`        | 24-hour   | Allowed                       |
| `16:00`     | 24-hour   | Minutes will be ignored       |
| `4PM`       | AM/PM     | Will be converted to 16       |
| `4:30PM`    | AM/PM     | Shows warning, uses 16        |

---

## 🗒️ Example Flow
```
Available Organizational Units:
0. OU=Domain Controllers,...
1. OU=Alumnos_BDD,...
...
Select OU number: 1

Select user:
0. Ana Mena Perez
1. Miguel Vazquez Bermejo
2. Apply to all users

Enter days (e.g., M-F or Sa): M-F
Enter start time (e.g., 16:00 or 4PM): 4PM
Enter end time (e.g., 9PM): 9PM
✓ Added range: M-F from 16:00 to 21:00

Save and apply? y
✅ LogonHours applied to Ana Mena Perez
```

---

## 🎓 Author
**Jose Luis Iñigo**  
a.k.a. Riskoo  
[https://joseluisinigo.work](https://joseluisinigo.work)  
info@joseluisinigo.work  
[github.com/joseluisinigo](https://github.com/joseluisinigo)

---

## ℹ️ License
MIT License

---

## 📊 Changelog

### v1.0.0 (Initial release)
- Basic OU selection and user filtering
- Manual definition of days and hours

### v1.1.0
- Added support for multiple time ranges
- Refined bitmask generation logic for AD logonHours
- Added validation and error messages

### v1.2.0
- Switched to `Sunday = 0` mapping for full AD compatibility
- Separated input for start/end times
- Added support for AM/PM and 24-hour time formats
- Warn users when using minutes (AD does not support them)

### v1.3.0
- Improved UX: preview of current ranges, removal support, safe confirmation
- More robust user and OU validation

### v1.4.0 (current)
- Clean documentation and inline help
- Final usability polish and visual improvements
- Fully tested and verified against AD policies

---

## ✨ TODOs / Ideas
- Export/import of time presets
- GPO assignment per group
- GUI wrapper for broader adoption

---

For bug reports or suggestions, please open an issue or contact the author directly.

