@echo off

chcp 65001 
cls

:: Banner anzeigen
echo.
echo ███████╗███████╗██████╗ ██╗ █████╗ ██╗                   
echo ██╔════╝██╔════╝██╔══██╗██║██╔══██╗██║                   
echo █████████╗█████╗  ██████╔╝██║███████║██║                   
echo ╚════██║██╔══╝  ██╔══██╗██║██╔══██║██║                   
echo ███████║███████╗██║  ██║██║██║  ██║███████╗             
echo ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝╚══════╝             
echo.
echo ██████╗██╗  ██╗███████╗ ██████╗██╗  ██╗███████╗██████╗ 
echo ██╔════╝██║  ██║██╔════╝██╔════╝██║ ██╔╝██╔════╝██╔══██╗
echo ██║     ███████║█████╗  ██║     █████╔╝ █████╗  ██████╔╝
echo ██║     ██╔══██║██╔══╝  ██║     ██╔═██╗ ██╔══╝  ██╔══██╗
echo ╚██████╗██║  ██║███████╗╚██████╗██║  ██╗███████╗██║  ██║
echo  ╚═════╝╚═╝  ╚═╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
echo.
echo                        Made by Tim
echo                      Discord: timm.5
echo.

:: Menü anzeigen
echo Please choose an option:
echo.
echo 1. Show Serial Numbers
echo 2. Show Installed Software (Optional)
echo 3. Exit
set /p option=Select an option: 

if "%option%"=="1" goto ShowSerials
if "%option%"=="2" goto AskShowSoftware
if "%option%"=="3" exit

:AskShowSoftware
echo Do you want to display the installed software? (y/n)
set /p showSoftware=Choose y for yes, n for no: 

if /i "%showSoftware%"=="y" goto ShowSoftware
if /i "%showSoftware%"=="n" goto ShowSerials

:ShowSoftware
echo Loading installed software, please wait...
:: Kurze Verzögerung simulieren
ping 127.0.0.1 -n 3 > nul
echo Installed Software
echo ---
powershell -Command "Get-WmiObject -Class Win32_Product | Select-Object Name, Version"

goto ShowSerials

:ShowSerials

echo.
echo.

echo GPU
echo ---
nvidia-smi --format=csv --query-gpu=name,serial,uuid
echo :

echo.

echo Baseboard
echo ---
powershell -Command "Get-WmiObject -Class Win32_BaseBoard | Select-Object Product, Manufacturer, Version, SerialNumber"

echo.

echo BIOS
echo ---
powershell -Command "Get-WmiObject -Class Win32_BIOS | Select-Object SerialNumber, SMBIOSMajorVersion, SMBIOSMinorVersion"

echo.

echo CPU
echo ---
powershell -Command "Get-WmiObject -Class Win32_Processor | Select-Object SerialNumber, ProcessorId"

echo.

echo CSProduct
echo ---
powershell -Command "Get-WmiObject -Class Win32_ComputerSystemProduct | Select-Object IdentifyingNumber, UUID"

echo.

echo Diskdrive
echo ---
powershell -Command "Get-WmiObject -Class Win32_DiskDrive | Select-Object Model, SerialNumber"

echo Volumes
echo ---
vol C:
vol D:
vol E:

echo .

echo RAM
echo ---
powershell -Command "Get-CimInstance -ClassName Win32_PhysicalMemory | Select-Object SerialNumber"

echo.

echo Network
echo ---
powershell -Command "Get-WmiObject -Class Win32_NetworkAdapter | Select-Object DeviceID, Name, MACAddress"

echo.

echo TPM
echo ---
powershell.exe -Command "Write-Host 'SHA256: ' -NoNewline; Write-Host (Get-TpmEndorsementKeyInfo -Hash Sha256).PublicKeyHash"
echo :

echo.

echo Windows Product Key
echo ---
powershell -Command "(Get-WmiObject -Query 'select * from SoftwareLicensingService').OA3xOriginalProductKey"

echo.

echo IP Addresses
echo ---
powershell -Command "Get-WmiObject -Class Win32_NetworkAdapterConfiguration | Select-Object IPAddress"

echo.
echo Press any key to exit...
pause >nul










