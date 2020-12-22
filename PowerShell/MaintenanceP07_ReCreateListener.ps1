<#
    Generate script to :
        - Remove Listener
        - Failover to 07
        - Recreate Listener on 07

    # to do: 
        - Primary:   ALTER AVAILABILITY GROUP [agname] MODIFY REPLICA ON N'(01 instance)' WITH (FAILOVER_MODE = MANUAL)
        - Secondary: ALTER AVAILABILITY GROUP [agname] MODIFY REPLICA ON N'(07 instance)' WITH (FAILOVER_MODE = AUTOMATIC)
#>

$destinationFile = 'C:\..\WindowsPowerShell\Scripts\LSN.txt'
"" | Out-File -FilePath $destinationFile -Force

$Listeners = Get-DbaRegisteredServer -SqlInstance 'CMS' | Where-Object {$_.Group -Like '*Prod*2014*Listener*'};

foreach ($lsn in $Listeners) {
    Write-Output $lsn.ServerName
    $ag = Get-DbaAvailabilityGroup -SqlInstance $lsn.ServerName
    
    $inst07 = $ag.AvailabilityReplicas | Where-Object Name -like *07* | Select Name

    $primary = $ag.PrimaryReplica
    $groupName = $ag.Name

    # éxclue les listeners déjà traités
    if ($primary -like "*P02*") {
        $l = Get-DbaAgListener -SqlInstance $lsn.ServerName -AvailabilityGroup $groupName
    
        $ipAddr = $l.AvailabilityGroupListenerIPAddresses.IPAddress
        $subnetIp = $l.AvailabilityGroupListenerIPAddresses.SubnetIP
        $subnetMask = $l.AvailabilityGroupListenerIPAddresses.SubnetIPv4Mask
        $port = $l.PortNumber
        
        "Remove-DbaAgListener -SqlInstance $($primary) -AvailabilityGroup $($groupName) -Listener $($l.Name)" | Out-File -FilePath $destinationFile -Append

        "Invoke-DbaAgFailover -SqlInstance $($inst07.Name) -AvailabilityGroup $($groupName)" | Out-File -FilePath $destinationFile -Append

        $cmd = "Add-DbaAgListener -SqlInstance $($inst07.Name) -AvailabilityGroup $($groupName) -Name $($l.Name) -IPAddress $($ipAddr) -SubnetIP $($subnetIp) -SubnetMask $($subnetMask) -Port $($port)"
        $cmd | Out-File -FilePath $destinationFile -Append
    
        "" | Out-File -FilePath $destinationFile -Append
     }
}
