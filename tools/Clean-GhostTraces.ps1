<#
================================================================================
 Clean-GhostTraces.ps1
 Xoa dau vet cua may A sau khi bung ghost (Macrium Reflect) sang may B.
 CHAY TREN MAY B, sau lan boot dau tien, bang quyen Administrator.

 LUU Y QUAN TRONG:
   - Cach dung chuan la sysprep /generalize tren A TRUOC khi tao ghost.
   - Script nay la ban don "hau ky" cho image da tao xong.
   - Machine SID KHONG the doi an toan bang script -> chi sysprep lam duoc.
     Neu ban khong dung Active Directory domain, trung SID thuong khong sao.
   - Backup truoc khi chay. Tu chiu trach nhiem.
================================================================================
#>

# ------------------------------------------------------------------ CONFIG ----
# Bat/tat tung nhom thao tac. $true = chay, $false = bo qua.
$Cfg = @{
    NewMachineGuid   = $true    # Sinh lai HKLM\...\Cryptography\MachineGuid
    ResetWindowsUpdate = $true  # Xoa SusClientId + SoftwareDistribution (da update win tren A)
    RemoveGhostDevices = $true  # Go thiet bi khong con ket noi (man hinh cu, USB, ...)
    ClearNetworkProfiles = $true# Xoa profile/lich su mang cua A
    ClearSetupApiLogs = $true   # Xoa C:\Windows\INF\setupapi.*.log
    ClearMountedDevices = $true  # Xoa HKLM\SYSTEM\MountedDevices (Windows tu dung lai)
    ClearBrowsers    = $true    # Xoa toan bo du lieu Edge/Chrome/Firefox (da luot web tren A)
    ClearEventLogs   = $true    # Xoa toan bo Event Log
    ClearPrefetchTemp = $true   # Xoa Prefetch + Temp + Recent
    RenameComputer   = $false   # Doi ten may (tranh trung ten tren mang). Xem $NewName ben duoi
    NewName          = "PC-B"   # Chi dung khi RenameComputer = $true
    DeleteUsnJournal = $false   # Xoa USN journal o C: (rui ro thap, mac dinh tat)
}

# --------------------------------------------------------------- ELEVATION ----
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$pr = New-Object Security.Principal.WindowsPrincipal($id)
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Can quyen Administrator. Dang khoi chay lai..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs `
        -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# ----------------------------------------------------------------- LOGGING ----
$LogFile = "$env:SystemDrive\Clean-GhostTraces_$(Get-Date -f yyyyMMdd_HHmmss).log"
Start-Transcript -Path $LogFile -Force | Out-Null
function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "    [OK] $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "    [!!] $msg" -ForegroundColor Yellow }

Write-Host "================ CLEAN GHOST TRACES (may B) ================" -ForegroundColor White

# ------------------------------------------------------ 1. MACHINE GUID -------
if ($Cfg.NewMachineGuid) {
    Step "Sinh lai MachineGUID (khoa dinh danh nhieu phan mem licensing dung)"
    try {
        $new = [guid]::NewGuid().ToString()
        $p = 'HKLM:\SOFTWARE\Microsoft\Cryptography'
        $old = (Get-ItemProperty $p -Name MachineGuid -EA Stop).MachineGuid
        Set-ItemProperty -Path $p -Name MachineGuid -Value $new
        Ok "MachineGuid: $old  ->  $new"
    } catch { Warn "Loi: $_" }
}

# ------------------------------------------------ 2. RESET WINDOWS UPDATE -----
if ($Cfg.ResetWindowsUpdate) {
    Step "Reset ID Windows Update (SusClientId) - vi da update win tren A"
    try {
        Stop-Service wuauserv -Force -EA SilentlyContinue
        Stop-Service bits    -Force -EA SilentlyContinue
        $wu = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate'
        foreach ($n in 'SusClientId','SusClientIDValidation','PingID','AccountDomainSid') {
            Remove-ItemProperty -Path $wu -Name $n -EA SilentlyContinue
        }
        Remove-Item "$env:SystemRoot\SoftwareDistribution" -Recurse -Force -EA SilentlyContinue
        Ok "Da xoa SusClientId va SoftwareDistribution (se tu tao lai)"
    } catch { Warn "Loi: $_" }
}

# ---------------------------------------------------- 3. GHOST DEVICES --------
if ($Cfg.RemoveGhostDevices) {
    Step "Go thiet bi khong con ket noi (man hinh/USB/o dia cu cua A)"
    try {
        $raw = pnputil /enum-devices /disconnected 2>$null
        $ids = $raw | Select-String 'Instance ID:\s*(.+)' |
               ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() }
        if (-not $ids) { Warn "Khong thay thiet bi disconnected (hoac pnputil cu)."; }
        $c = 0
        foreach ($id in $ids) {
            pnputil /remove-device "$id" 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { $c++ }
        }
        Ok "Da go $c thiet bi ghost."
    } catch { Warn "Loi: $_" }
}

# ------------------------------------------------ 4. NETWORK PROFILES ---------
if ($Cfg.ClearNetworkProfiles) {
    Step "Xoa profile/chu ky mang cua A (chua MAC gateway mang cu)"
    $nl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList'
    foreach ($sub in 'Profiles','Signatures\Unmanaged','Signatures\Managed') {
        Remove-Item "$nl\$sub\*" -Recurse -Force -EA SilentlyContinue
    }
    Ok "Da xoa NetworkList profiles/signatures."
}

# ------------------------------------------------ 5. SETUPAPI LOGS ------------
if ($Cfg.ClearSetupApiLogs) {
    Step "Xoa setupapi log (nhat ky cai driver + serial thiet bi cua A)"
    Remove-Item "$env:SystemRoot\INF\setupapi.dev*.log"   -Force -EA SilentlyContinue
    Remove-Item "$env:SystemRoot\INF\setupapi.setup*.log" -Force -EA SilentlyContinue
    Ok "Da xoa setupapi logs."
}

# ------------------------------------------------ 6. MOUNTED DEVICES ----------
if ($Cfg.ClearMountedDevices) {
    Step "Xoa HKLM\SYSTEM\MountedDevices (lich su volume cua A)"
    Warn "Windows se dung lai o lan boot ke tiep. Neu he thong 1 o dia thi an toan."
    try {
        $md = 'HKLM:\SYSTEM\MountedDevices'
        (Get-Item $md).Property | ForEach-Object {
            Remove-ItemProperty -Path $md -Name $_ -EA SilentlyContinue
        }
        Ok "Da xoa MountedDevices."
    } catch { Warn "Loi: $_" }
}

# ------------------------------------------------ 7. BROWSER TRACES -----------
if ($Cfg.ClearBrowsers) {
    Step "Xoa du lieu trinh duyet (da luot web tren A)"
    Warn "Se xoa CA bookmark/mat khau/cai dat cua trinh duyet trong image."
    'msedge','chrome','firefox','brave' | ForEach-Object {
        Get-Process $_ -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
    }
    Start-Sleep 2
    Get-ChildItem "$env:SystemDrive\Users" -Directory -EA SilentlyContinue | ForEach-Object {
        $u = $_.FullName
        $targets = @(
            "$u\AppData\Local\Microsoft\Edge\User Data",
            "$u\AppData\Local\Google\Chrome\User Data",
            "$u\AppData\Local\BraveSoftware\Brave-Browser\User Data",
            "$u\AppData\Roaming\Mozilla\Firefox\Profiles"
        )
        foreach ($t in $targets) {
            if (Test-Path $t) { Remove-Item "$t\*" -Recurse -Force -EA SilentlyContinue }
        }
    }
    Ok "Da xoa du lieu Edge/Chrome/Brave/Firefox cho moi user."
}

# ------------------------------------------------ 8. EVENT LOGS ---------------
if ($Cfg.ClearEventLogs) {
    Step "Xoa toan bo Event Log"
    $n = 0
    wevtutil el | ForEach-Object {
        wevtutil cl "$_" 2>$null; if ($LASTEXITCODE -eq 0) { $n++ }
    }
    Ok "Da xoa $n event log."
}

# ------------------------------------------------ 9. PREFETCH / TEMP ----------
if ($Cfg.ClearPrefetchTemp) {
    Step "Xoa Prefetch / Temp / Recent"
    Remove-Item "$env:SystemRoot\Prefetch\*" -Recurse -Force -EA SilentlyContinue
    Remove-Item "$env:SystemRoot\Temp\*"     -Recurse -Force -EA SilentlyContinue
    Get-ChildItem "$env:SystemDrive\Users" -Directory -EA SilentlyContinue | ForEach-Object {
        Remove-Item "$($_.FullName)\AppData\Local\Temp\*" -Recurse -Force -EA SilentlyContinue
        Remove-Item "$($_.FullName)\AppData\Roaming\Microsoft\Windows\Recent\*" -Recurse -Force -EA SilentlyContinue
    }
    Ok "Da xoa Prefetch/Temp/Recent."
}

# ------------------------------------------------ 10. USN JOURNAL -------------
if ($Cfg.DeleteUsnJournal) {
    Step "Xoa USN journal o C:"
    fsutil usn deletejournal /d $env:SystemDrive 2>$null | Out-Null
    Ok "Da xoa USN journal (se tu tao lai)."
}

# ------------------------------------------------ 11. RENAME COMPUTER ---------
if ($Cfg.RenameComputer) {
    Step "Doi ten may thanh '$($Cfg.NewName)'"
    try {
        Rename-Computer -NewName $Cfg.NewName -Force -EA Stop
        Ok "Da doi ten. Se ap dung sau khi reboot."
    } catch { Warn "Loi: $_" }
}

# ------------------------------------------------------------------- DONE -----
Write-Host "`n================ HOAN TAT ================" -ForegroundColor White
Write-Host "Log luu tai: $LogFile" -ForegroundColor Gray
Write-Host @"

CON LAI CAN LAM THU CONG (neu muon triet de):
  - Machine SID: script khong doi duoc. Muon doi -> chay sysprep (xem duoi).
  - Disk GUID: khong tu doi vi rui ro voi BCD boot. Xem: Get-Disk | Select Guid
  - Kich hoat Windows: may B thuong mat activation, kich hoat lai bang key rieng.
  - BitLocker/Windows Hello: seal theo TPM cua A -> B se doi recovery key/reset.

TUY CHON DON TRIET DE (regen ca SID) - chay tren B:
  C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /reboot
  (Luu y: se chay lai OOBE nhu may moi cai.)

"@ -ForegroundColor DarkGray

Stop-Transcript | Out-Null
Write-Host "Nen KHOI DONG LAI may B ngay bay gio de ap dung." -ForegroundColor Yellow
