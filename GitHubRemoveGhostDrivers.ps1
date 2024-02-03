Set-ExecutionPolicy Bypass -scope Process -Confirm:$false -Force -Verb

function ghost {

Param(
  [array]$FilterByClass,
  [array]$NarrowByClass,
  [array]$FilterByFriendlyName,
  [array]$NarrowByFriendlyName,
  [switch]$Force
)

$removeDevices = $true
if ($FilterByClass -ne $null) {
    write-host "FilterByClass: $FilterByClass"
}

if ($NarrowByClass -ne $null) {
    write-host "NarrowByClass: $NarrowByClass"
}

if ($FilterByFriendlyName -ne $null) {
    write-host "FilterByFriendlyName: $FilterByFriendlyName"
}

if ($NarrowByFriendlyName -ne $null) {
    write-host "NarrowByFriendlyName: $NarrowByFriendlyName"
}

if ($Force -eq $true) {
    write-host "Each removal will happen without any confirmation: $Force"
}

function Filter-Device {
    Param (
        [System.Object]$dev
    )
    $Class = $dev.Class
    $FriendlyName = $dev.FriendlyName
    $matchFilter = $false

    if (($matchFilter -eq $false) -and ($FilterByClass -ne $null)) {
        foreach ($ClassFilter in $FilterByClass) {
            if ($ClassFilter -eq $Class) {
                Write-verbose "Class filter match $ClassFilter, skipping"
                $matchFilter = $true
                break
            }
        }
    }
    if (($matchFilter -eq $false) -and ($NarrowByClass -ne $null)) {
        $shouldInclude = $false
        foreach ($ClassFilter in $NarrowByClass) {
            if ($ClassFilter -eq $Class) {
                $shouldInclude = $true
                break
            }
        }
        $matchFilter = !$shouldInclude
    }
    if (($matchFilter -eq $false) -and ($FilterByFriendlyName -ne $null)) {
        foreach ($FriendlyNameFilter in $FilterByFriendlyName) {
            if ($FriendlyName -like '*'+$FriendlyNameFilter+'*') {
                Write-verbose "FriendlyName filter match $FriendlyName, skipping"
                $matchFilter = $true
                break
            }
        }
    }
    if (($matchFilter -eq $false) -and ($NarrowByFriendlyName -ne $null)) {
        $shouldInclude = $false
        foreach ($FriendlyNameFilter in $NarrowByFriendlyName) {
            if ($FriendlyName -like '*'+$FriendlyNameFilter+'*') {
                $shouldInclude = $true
                break
            }
        }
        $matchFilter = !$shouldInclude
    }
    return $matchFilter
}

function Filter-Devices {
    Param (
        [array]$devices
    )
    $filteredDevices = @()
    foreach ($dev in $devices) {
        $matchFilter = Filter-Device -Dev $dev
        if ($matchFilter -eq $false) {
            $filteredDevices += @($dev)
        }
    }
    return $filteredDevices
}
function Get-Ghost-Devices {
    Param (
        [array]$devices
    )
    return ($devices | where {$_.InstallState -eq $false} | sort -Property FriendlyName)
}

$setupapi = @"
using System;
using System.Diagnostics;
using System.Text;
using System.Runtime.InteropServices;
namespace Win32
{
    public static class SetupApi
    {
         
        [DllImport("setupapi.dll", CharSet = CharSet.Auto)]
        public static extern IntPtr SetupDiGetClassDevs(
           ref Guid ClassGuid,
           IntPtr Enumerator,
           IntPtr hwndParent,
           int Flags
        );
    
        [DllImport("setupapi.dll", CharSet = CharSet.Auto)]
        public static extern IntPtr SetupDiGetClassDevs(
           IntPtr ClassGuid,
           string Enumerator,
           IntPtr hwndParent,
           int Flags
        );
        
        [DllImport("setupapi.dll", CharSet = CharSet.Auto, SetLastError = true)]
        public static extern bool SetupDiEnumDeviceInfo(
            IntPtr DeviceInfoSet,
            uint MemberIndex,
            ref SP_DEVINFO_DATA DeviceInfoData
        );
    
        [DllImport("setupapi.dll", SetLastError = true)]
        public static extern bool SetupDiDestroyDeviceInfoList(
            IntPtr DeviceInfoSet
        );
        [DllImport("setupapi.dll", CharSet = CharSet.Auto, SetLastError = true)]
        public static extern bool SetupDiGetDeviceRegistryProperty(
            IntPtr deviceInfoSet,
            ref SP_DEVINFO_DATA deviceInfoData,
            uint property,
            out UInt32 propertyRegDataType,
            byte[] propertyBuffer,
            uint propertyBufferSize,
            out UInt32 requiredSize
        );
        [DllImport("setupapi.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern bool SetupDiGetDeviceInstanceId(
            IntPtr DeviceInfoSet,
            ref SP_DEVINFO_DATA DeviceInfoData,
            StringBuilder DeviceInstanceId,
            int DeviceInstanceIdSize,
            out int RequiredSize
        );

    
        [DllImport("setupapi.dll", CharSet = CharSet.Auto, SetLastError = true)]
        public static extern bool SetupDiRemoveDevice(IntPtr DeviceInfoSet,ref SP_DEVINFO_DATA DeviceInfoData);
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct SP_DEVINFO_DATA
    {
       public uint cbSize;
       public Guid classGuid;
       public uint devInst;
       public IntPtr reserved;
    }
    [Flags]
    public enum DiGetClassFlags : uint
    {
        DIGCF_DEFAULT       = 0x00000001,
        DIGCF_PRESENT       = 0x00000002,
        DIGCF_ALLCLASSES    = 0x00000004,
        DIGCF_PROFILE       = 0x00000008,
        DIGCF_DEVICEINTERFACE   = 0x00000010,
    }
    public enum SetupDiGetDeviceRegistryPropertyEnum : uint
    {
         SPDRP_DEVICEDESC          = 0x00000000,
         SPDRP_HARDWAREID          = 0x00000001,
         SPDRP_COMPATIBLEIDS           = 0x00000002,
         SPDRP_UNUSED0             = 0x00000003,
         SPDRP_SERVICE             = 0x00000004,
         SPDRP_UNUSED1             = 0x00000005,
         SPDRP_UNUSED2             = 0x00000006,
         SPDRP_CLASS               = 0x00000007,
         SPDRP_CLASSGUID           = 0x00000008,
         SPDRP_DRIVER              = 0x00000009,
         SPDRP_CONFIGFLAGS         = 0x0000000A,
         SPDRP_MFG             = 0x0000000B,
         SPDRP_FRIENDLYNAME        = 0x0000000C,
         SPDRP_LOCATION_INFORMATION    = 0x0000000D,
         SPDRP_PHYSICAL_DEVICE_OBJECT_NAME = 0x0000000E,
         SPDRP_CAPABILITIES        = 0x0000000F,
         SPDRP_UI_NUMBER           = 0x00000010,
         SPDRP_UPPERFILTERS        = 0x00000011,
         SPDRP_LOWERFILTERS        = 0x00000012,
         SPDRP_BUSTYPEGUID         = 0x00000013,
         SPDRP_LEGACYBUSTYPE           = 0x00000014,
         SPDRP_BUSNUMBER           = 0x00000015,
         SPDRP_ENUMERATOR_NAME         = 0x00000016,
         SPDRP_SECURITY            = 0x00000017,
         SPDRP_SECURITY_SDS        = 0x00000018,
         SPDRP_DEVTYPE             = 0x00000019,
         SPDRP_EXCLUSIVE           = 0x0000001A,
         SPDRP_CHARACTERISTICS         = 0x0000001B,
         SPDRP_ADDRESS             = 0x0000001C,
         SPDRP_UI_NUMBER_DESC_FORMAT       = 0X0000001D,
         SPDRP_DEVICE_POWER_DATA       = 0x0000001E,
         SPDRP_REMOVAL_POLICY          = 0x0000001F,
         SPDRP_REMOVAL_POLICY_HW_DEFAULT   = 0x00000020,
         SPDRP_REMOVAL_POLICY_OVERRIDE     = 0x00000021,
         SPDRP_INSTALL_STATE           = 0x00000022,
         SPDRP_LOCATION_PATHS          = 0x00000023,
         SPDRP_BASE_CONTAINERID        = 0x00000024
    }
}
"@
Add-Type -TypeDefinition $setupapi

    
    $removeArray = @()
    
    $array = @()

    $setupClass = [Guid]::Empty
    
    $devs = [Win32.SetupApi]::SetupDiGetClassDevs([ref]$setupClass, [IntPtr]::Zero, [IntPtr]::Zero, [Win32.DiGetClassFlags]::DIGCF_ALLCLASSES)

    
    $devInfo = new-object Win32.SP_DEVINFO_DATA
    $devInfo.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($devInfo)

    
    $devCount = 0
    
    while([Win32.SetupApi]::SetupDiEnumDeviceInfo($devs, $devCount, [ref]$devInfo)) {

        
        $propType = 0
        
        [byte[]]$propBuffer = $null
        $propBufferSize = 0
        
        [Win32.SetupApi]::SetupDiGetDeviceRegistryProperty($devs, [ref]$devInfo, [Win32.SetupDiGetDeviceRegistryPropertyEnum]::SPDRP_FRIENDLYNAME, [ref]$propType, $propBuffer, 0, [ref]$propBufferSize) | Out-null
        
        [byte[]]$propBuffer = New-Object byte[] $propBufferSize

        
        $propTypeHWID = 0
        [byte[]]$propBufferHWID = $null
        $propBufferSizeHWID = 0
        [Win32.SetupApi]::SetupDiGetDeviceRegistryProperty($devs, [ref]$devInfo, [Win32.SetupDiGetDeviceRegistryPropertyEnum]::SPDRP_HARDWAREID, [ref]$propTypeHWID, $propBufferHWID, 0, [ref]$propBufferSizeHWID) | Out-null
        [byte[]]$propBufferHWID = New-Object byte[] $propBufferSizeHWID

        
        $propTypeDD = 0
        [byte[]]$propBufferDD = $null
        $propBufferSizeDD = 0
        [Win32.SetupApi]::SetupDiGetDeviceRegistryProperty($devs, [ref]$devInfo, [Win32.SetupDiGetDeviceRegistryPropertyEnum]::SPDRP_DEVICEDESC, [ref]$propTypeDD, $propBufferDD, 0, [ref]$propBufferSizeDD) | Out-null
        [byte[]]$propBufferDD = New-Object byte[] $propBufferSizeDD

        
        $propTypeIS = 0
        [byte[]]$propBufferIS = $null
        $propBufferSizeIS = 0
        [Win32.SetupApi]::SetupDiGetDeviceRegistryProperty($devs, [ref]$devInfo, [Win32.SetupDiGetDeviceRegistryPropertyEnum]::SPDRP_INSTALL_STATE, [ref]$propTypeIS, $propBufferIS, 0, [ref]$propBufferSizeIS) | Out-null
        [byte[]]$propBufferIS = New-Object byte[] $propBufferSizeIS

        
        $propTypeCLSS = 0
        [byte[]]$propBufferCLSS = $null
        $propBufferSizeCLSS = 0
        [Win32.SetupApi]::SetupDiGetDeviceRegistryProperty($devs, [ref]$devInfo, [Win32.SetupDiGetDeviceRegistryPropertyEnum]::SPDRP_CLASS, [ref]$propTypeCLSS, $propBufferCLSS, 0, [ref]$propBufferSizeCLSS) | Out-null
        [byte[]]$propBufferCLSS = New-Object byte[] $propBufferSizeCLSS
        [Win32.SetupApi]::SetupDiGetDeviceRegistryProperty($devs, [ref]$devInfo,[Win32.SetupDiGetDeviceRegistryPropertyEnum]::SPDRP_CLASS, [ref]$propTypeCLSS, $propBufferCLSS, $propBufferSizeCLSS, [ref]$propBufferSizeCLSS)  | out-null
        $Class = [System.Text.Encoding]::Unicode.GetString($propBufferCLSS)

        
        if(![Win32.SetupApi]::SetupDiGetDeviceRegistryProperty($devs, [ref]$devInfo,[Win32.SetupDiGetDeviceRegistryPropertyEnum]::SPDRP_FRIENDLYNAME, [ref]$propType, $propBuffer, $propBufferSize, [ref]$propBufferSize)){
            [Win32.SetupApi]::SetupDiGetDeviceRegistryProperty($devs, [ref]$devInfo,[Win32.SetupDiGetDeviceRegistryPropertyEnum]::SPDRP_DEVICEDESC, [ref]$propTypeDD, $propBufferDD, $propBufferSizeDD, [ref]$propBufferSizeDD)  | out-null
            $FriendlyName = [System.Text.Encoding]::Unicode.GetString($propBufferDD)
            
            if ($FriendlyName.Length -ge 1) {
                $FriendlyName = $FriendlyName.Substring(0,$FriendlyName.Length-1)
            }
        } else {
            
            $FriendlyName = [System.Text.Encoding]::Unicode.GetString($propBuffer)
            
            if ($FriendlyName.Length -ge 1) {
                $FriendlyName = $FriendlyName.Substring(0,$FriendlyName.Length-1)
            }
        }

        
        $InstallState = [Win32.SetupApi]::SetupDiGetDeviceRegistryProperty($devs, [ref]$devInfo,[Win32.SetupDiGetDeviceRegistryPropertyEnum]::SPDRP_INSTALL_STATE, [ref]$propTypeIS, $propBufferIS, $propBufferSizeIS, [ref]$propBufferSizeIS)

        
        if(![Win32.SetupApi]::SetupDiGetDeviceRegistryProperty($devs, [ref]$devInfo,[Win32.SetupDiGetDeviceRegistryPropertyEnum]::SPDRP_HARDWAREID, [ref]$propTypeHWID, $propBufferHWID, $propBufferSizeHWID, [ref]$propBufferSizeHWID)){
            
            $HWID = ""
        } else {
            
            $HWID = [System.Text.Encoding]::Unicode.GetString($propBufferHWID)
            
            $HWID = $HWID.split([char]0x0000)[0].ToUpper()
        }

        
        $device = New-Object System.Object
        $device | Add-Member -type NoteProperty -name FriendlyName -value $FriendlyName
        $device | Add-Member -type NoteProperty -name HWID -value $HWID
        $device | Add-Member -type NoteProperty -name InstallState -value $InstallState
        $device | Add-Member -type NoteProperty -name Class -value $Class
        if ($array.count -le 0) {
            
            
            sleep 1
        }
        $array += @($device)

        
        if ($removeDevices -eq $true) {
            
            $matchFilter = Filter-Device -Dev $device

            if ($InstallState -eq $False) {
                if ($matchFilter -eq $false) {
                    $message  = "Attempting to remove device $FriendlyName"
                    $confirmed = $false
                    if (!$Force -eq $true) {
                        $question = 'Are you sure you want to proceed?'
                        $choices  = '&Yes', '&No'
                        $decision = $Host.UI.PromptForChoice($message, $question, $choices, 1)
                        if ($decision -eq 0) {
                            $confirmed = $true
                        }
                    } else {
                        $confirmed = $true
                    }
                    if ($confirmed -eq $true) {
                        Write-Host $message -ForegroundColor Yellow
                        $removeObj = New-Object System.Object
                        $removeObj | Add-Member -type NoteProperty -name FriendlyName -value $FriendlyName
                        $removeObj | Add-Member -type NoteProperty -name HWID -value $HWID
                        $removeObj | Add-Member -type NoteProperty -name InstallState -value $InstallState
                        $removeObj | Add-Member -type NoteProperty -name Class -value $Class
                        $removeArray += @($removeObj)
                        if([Win32.SetupApi]::SetupDiRemoveDevice($devs, [ref]$devInfo)){
                            Write-Host "Removed device $FriendlyName"  -ForegroundColor Green
                        } else {
                            Write-Host "Failed to remove device $FriendlyName" -ForegroundColor Red
                        }
                    } else {
                        Write-Host "OK, skipped" -ForegroundColor Yellow
                    }
                } else {
                    write-host "Filter matched. Skipping $FriendlyName" -ForegroundColor Yellow
                }
            }
        }
        $devcount++
    }

   if ($removeDevices -eq $true) {
        write-host "Removed devices:"
        $removeArray  | sort -Property FriendlyName | ft
        write-host "Total removed devices     : $($removeArray.count)"
        return $removeArray | out-null
    }
}

ghost -Force | Out-Null