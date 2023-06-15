# This script is designed to take a CSV file complete with switch port numbers, types, names and vlans, and configure it using the Meraki API
# This script was developed by Brent Morvan
# Double check all variables before running and USE AT YOUR OWN RISK!

#==============================================
# Read in and validate the Switch serial number
#==============================================
$Serial = Read-Host -Prompt 'Please enter the switch serial number (xxxx-xxxx-xxxx)'
while($serial -notmatch "^([A-Za-z0-9]{4})-([A-Za-z0-9]{4})-([A-Za-z0-9]{4})$")
{
    Write-host "Incorrectly formatted serial number. Please try again`n"
    $Serial = Read-Host -Prompt 'Please enter the switch serial number (xxxx-xxxx-xxxx)'
}
#================================================

#==================================
# Read in and validate the CSV file
#==================================
do {
$CsvFailed = $false
$CsvLocation = Read-Host -Prompt 'Please enter the full path of the CSV file (Eg. c:\Temp\ports.csv)'
Try{
    $ports = Import-Csv -Path "$CsvLocation"
} catch {
Write-Host "Unable to find or interpret .csv file`n"
$CsvFailed = $true}
}
while ($CsvFailed)

#====================================

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


Write-Host "--------------------------------------------------------"
Write-Host "`nConfiguring device $serial using configuration from $CsvLocation `n"


#=================================================================
# Iterate through the ports as per the CSV file, build
# the JSON with the correct parameters and push the configuration
#=================================================================
ForEach ($PortID in $ports){

# Check if port type is access
If ($PortID.type -eq "access"){ 

$Body= @{
"type"="access";
"vlan"=$PortID.vlan;
"name"=$PortID.name
}

}
# Check if port type is trunk
Elseif ($PortID.type -eq "trunk"){
$Body= @{
"type"="trunk";
"vlan"=$PortID.vlan;
"name"=$PortID.name;
"allowedVlans"=$portID.allowedvlans
}
}

$PortNumber = $PortID.port
$vlan=$PortID.vlan
$name=$PortID.name

Write-Output "Configuring Port $PortNumber with Vlan $vlan and name $name"

# Execute the API call to configure the port
$request = Invoke-RestMethod -Method PUT -Uri "https://api.meraki.com/api/v1/devices/$Serial/switch/ports/$PortNumber" -Headers $Headers -Body ($Body|ConvertTo-Json)

}
#======================================================================================
