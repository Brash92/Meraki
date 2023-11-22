# This script is designed to take a CSV file complete with switch port numbers, types, names and vlans, and configure it using the Meraki API
# Double check all variables before running and USE AT YOUR OWN RISK!

Write-Host "=============================DISCLAIMER============================================================"
Write-Host "This script is designed to automate switchport configuration based on a provided JSON Backup file."
Write-Host "This is not an official script and comes with no guarantees, warranties or support."
Write-Host "Use At Your Own Risk!"
Write-Host "===================================================================================================`n"


# Get date for backup filename
$date = Get-Date  -Format o | ForEach-Object { $_ -replace ":", "_" } | ForEach-Object { $_ -replace "-", "_" }


#====================================
# Read in and validate the API Key
#===================================

do {
$APIFailed = $false
$APIKey = Read-Host -Prompt 'Please enter your API key'
Try{
    # Set the headers with the API Key
    $headers = @{
        "Content-Type" = "application/json"
        "X-Cisco-Meraki-API-Key" = $APIKey
    }
    $request = Invoke-RestMethod -Method GET -Uri "https://api.meraki.com/api/v1/organizations" -Headers $Headers
} 
catch {
    if( $_.Exception.Response.StatusCode.Value__ -eq 401 )
        {Write-Host "Incorrect API Key. Please try again`n"}
    if( $_.Exception.Response.StatusCode.Value__ -eq 403 )
        {Write-Host "You do not have permissions in this organization.`n"}
    $APIFailed = $true}
}
while ($APIFailed)

#========================================================


#============================================================
# Read in and validate the Switch serial number and validate
#============================================================

do {

$SwitchName = ""
$SwitchVerification = ""

# Prompt for switch SN# and do basic input validation
$Serial = Read-Host -Prompt 'Please enter the switch serial number (xxxx-xxxx-xxxx)'
while($serial -notmatch "^([A-Za-z0-9]{4})-([A-Za-z0-9]{4})-([A-Za-z0-9]{4})$")
{
    Write-host "Incorrectly formatted serial number. Please try again`n"
    $Serial = Read-Host -Prompt 'Please enter the switch serial number (xxxx-xxxx-xxxx)'
}


# Perform a lookup of the SN# to validate it is in the Organisation, and to get the device name
Try{
    # Set the headers with the API Key
    $headers = @{
        "Content-Type" = "application/json"
        "X-Cisco-Meraki-API-Key" = $APIKey
    }
        $device = Invoke-RestMethod -Method GET -Uri "https://api.meraki.com/api/v1/devices/$Serial" -Headers $Headers
            if ($Serial -eq $device.serial)
                {
                    $SwitchName = $device.name
                } 
    }
 
catch {
    if( $_.Exception.Response.StatusCode.Value__ -eq 401 )
        {Write-Host "Incorrect API Key. Please try again`n"}
    if( $_.Exception.Response.StatusCode.Value__ -eq 403 )
        {Write-Host "You do not have permissions in this organization.`n"}
    else{Write-Host "Switch not found in your Organisation. Please try again.`n"}
        $SwitchVerification = "No"
      }

# Prompt the user to confirm that this is indeed the switch that they are wanting to make changes on
#if ($SwitchVerification -notmatch "^(?:Yes\b|No\b)")
if ($SwitchVerification -notmatch "^(?:Yes\b|No\b|yes\b|no\b|Y\b|N\b|y\b|n\b)")
{
$SwitchVerification = Read-Host -Prompt "You are about to edit the switch $SwitchName. Type `"Yes`" to proceed or `"No`" to re-enter the Serial Number"
}
while($SwitchVerification -notmatch "^(?:Yes\b|No\b|yes\b|no\b|Y\b|N\b|y\b|n\b)")
{
    Write-host "Invalid entry. Please try again.`n"
    $SwitchVerification = Read-Host -Prompt "You are about to edit the switch $SwitchName. Type `"Yes`" to proceed or `"No`" to re-enter the Serial Number"
}
}
while (($SwitchVerification -eq "No") -or ($SwitchVerification -eq "N"))

#================================================


#===========================================
# Read in and validate the JSON Backup file
#===========================================
do {
$JsonFailed = $false
$JsonLocation = Read-Host -Prompt 'Please enter the full path of the JSON file (Eg. c:\Temp\ports.json)'
Try{
    $portConfig = Get-Content -Raw -Path "$JsonLocation" | ConvertFrom-Json
} catch {
Write-Host "Unable to find or interpret .json file`n"
$JsonFailed = $true}
}
while ($JsonFailed)

#====================================

#===================================================================
# Create a backup JSON file of the existing configuration
#===================================================================

Write-Host "--------------------------------------------------------`n"
write-host "Creating backup of existing configuration"

    $backupParentPath = Split-Path -Path $JsonLocation
    $backupPath = "$backupParentPath`\$Switchname`_backup`_$date.json"
    $request = Invoke-RestMethod -Method GET -Uri "https://api.meraki.com/api/v1/devices/$Serial/switch/ports" -Headers $Headers
    $request | ConvertTo-Json -depth 100 | Out-File "$backupPath"

write-host "Backup written to $backupPath"

#=====================================================================


#============================================
# Configure switch using provided JSON file
#============================================

Write-Host "`nConfiguring device $SwitchName `($serial`) using configuration from $JsonLocation `n"


ForEach ($port in $portConfig){

    $portID = $port.portId
    $Body = $port
    write-host "Configuring port $portID"
    $request = Invoke-RestMethod -Method PUT -Uri "https://api.meraki.com/api/v1/devices/$serial/switch/ports/$portID" -Headers $Headers -Body ($Body|ConvertTo-Json)
}

#============================================