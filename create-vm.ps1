<#
    create-vm.ps1
	.SYNOPSIS
	Create a new vm from a template
	.DESCRIPTION
    Connect to a vCenter and create a new vm from a template.
    Create the vm with specified specs (CPU, memory, ...)
    note: you'll need vmware POWERCLI

#>



######################################
# ignore errors
######################################

$ErrorActionPreference = "SilentlyContinue"

######################################
# connecting to the vCenter
######################################


write-host "Select a vCenter to connect to" -ForegroundColor Yellow
do {
    write-host ""
    write-host "A - SERVERx (vCenter)"
    write-host "B - SERVERy (Horizon)"
    write-host -nonewline "Type your choice and press Enter: "
    $choice = read-host
    write-host ""
    $ok = $choice -match '^[ab]+$'
    if ( -not $ok) { write-host "Invalid selection" }
} until ( $ok )
switch -Regex ( $choice ) {
    "A" {
        $vCenter = "SERVERx"
        write-host "You picked SERVERx.pa.be to connect to" -ForegroundColor Yellow
    }
    "B"{
        $vCenter = "SERVERy"
        write-host "You picked SERVERy to connect to" -ForegroundColor Yellow
    }
}
write-host "Connecting to the vCenter $vCenter" -ForegroundColor Yellow
$vCcred = get-credential
Connect-VIServer $vCenter -credential $vCcred -force


######################################
# creating new vm
######################################


#default settings
$vmTemplate = Get-Template -Name "WindowsServer2019"
$network = "VLANz"

write-host "provide information to create a new vm" -ForegroundColor Yellow
$vmname = read-host "enter the vm's name"


#test vmname in vCenter
Write-Host "checking if the name is known in vCenter" -ForegroundColor Yellow 
$testname = Get-VM $vmname
if ($testname -eq $null ){
    write-host "Name $vmname is not present in the vCenter" -ForegroundColor Green 
    }
else {
    write-host "Warning! $vmname already found in vCenter. Find a new name and run the script again." -ForegroundColor Red
    Exit
    }


#get vCenter data
write-host "provide the host where the vm must be deployed on:" -ForegroundColor Yellow
$vChosts = Get-VMHost
$hostmenu = @{}
for ($i=1;$i -le $vChosts.count; $i++) {
    Write-Host "$i. $($vChosts[$i-1].name)"
    $hostmenu.Add($i,($vChosts[$i-1].name))
    }

[int]$hostans = Read-Host 'Enter the number of the ESXi host you want to use.'
$targetvmhost = $hostmenu.Item($hostans)
Get-vmhost $targetvmhost

write-host "looking up connected datastores on $targetvmhost" -ForegroundColor Yellow
write-host "provide the datastore for the vm" -ForegroundColor Yellow
Get-vmhost $targetvmhost | get-datastore | select name, capacityGB, freespaceGB | ft

$datastore = Get-VMHost $TargetVMHost | Get-Datastore
$dsmenu = @{}
for ($i=1;$i -le $datastore.count; $i++) {
    Write-Host "$i. $($datastore[$i-1].name)"
    $dsmenu.Add($i,($datastore[$i-1].name))
    }
[int]$dsans = Read-Host 'Enter the number of the datastore you want to use.'


#get vm specs
write-host "The default template for the vm is $vmTemplate. Provide the basic specs for the machine" -ForegroundColor Yellow
$cpu = read-host "how many cpu sockets?"
$cores = read-host "how many cores per socket?"
$mem = read-host "how many GB memory needed?"


#create new vm
write-host "creating a vm with these specs:
- name: $vmname
- cpu: $cpu
- cores per socket: $cores
- memory: $mem GB
- network (default): $network
- template (default): $vmTemplate

vm will be created on $TargetVMHost and stored on $datastore

" -ForegroundColor Yellow

do {
    Write-Host "Is this information correct? (y/n)"
    $choice = read-host
    $ok = $choice -match '^[yn]+$'
    if ( -not $ok) { write-host "Invalid selection" }
} until ( $ok )

switch -Regex ( $choice ) {
    "y" {write-host "Preparing to create the vm" -ForegroundColor Yellow}
    "n" {
        write-host "exiting script" -ForegroundColor red
        exit
        }
}

New-VM -Name $vmname -Template $vmTemplate -vmhost $TargetVMHost -Datastore $datastore 


#applying settings
write-host "vm $vmname is created. Applying settings... " -ForegroundColor Yellow

$VM=Get-VM -Name $vmname
$VMSpec=New-Object –Type VMware.Vim.VirtualMAchineConfigSpec –Property @{“NumCoresPerSocket” = $cores}
$VM.ExtensionData.ReconfigVM_Task($VMSpec)
$VM | Set-VM -NumCPU $cores -MemoryGB $mem -Confirm:$false
$VM | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $network -Confirm:$false
#-Confirm:$false


#starting vm
write-host "Starting up the new vm...." -ForegroundColor Yellow
Start-VM $vmname



######################################
# disconnect vCenter
######################################

Disconnect-VIServer

######################################
# enable errors
######################################

$ErrorActionPreference = "Continue"


