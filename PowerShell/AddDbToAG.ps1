
<#
Take a Primary Replica instance as input
    - Add all databases to the Availability Group.
    - Maunal Seeding => Backup -> Copy -> Restore


#inspired by code from ijeb
#https://github.com/sqlcollaborative/dbatools/issues/4610


#  todo:  restore login SA
#  todo:  prendre en compte le cas où la base n'est pas déjà dans l'AG
#>

$allbackups = @{}
$Instance = 'primaryInstance' #primary instance
$AG = 'AvailabilityGroupName'

#$Database = Get-DbaAgDatabase -SqlInstance $Instance -AvailabilityGroup $AG
$Database = Get-DbaDatabase -SqlInstance $Instance
$primary = Get-DbaAgReplica -SqlInstance $Instance | Where-Object Role -eq 'Primary'
$secondaries = Get-DbaAgReplica -SqlInstance $Instance | Where-Object Role -eq 'Secondary'

foreach ($db in $Database) {
    #Write-Output $db
    $primaryDb = Get-DbaDatabase -SqlInstance $Primary.Name -Database $db.Name
    
    foreach ($second in $secondaries) {
        #Write-Output $second
        #$primaryDb = Get-DbaDatabase -SqlInstance $Primary.Name -Database $db.Name
        Write-Output "priamry: " +$db
        $secondaryDb = Get-DbaDatabase -SqlInstance $second.Name -Database $db.Name
        #Write-Output $secondaryDb
        Write-Output "secondary: " +$secondaryDb
        if (-not $secondaryDb) {
            Write-Output $db.Name
            # Backup Primary 
            $fullbackup = $primarydb | Backup-DbaDatabase -Checksum -CompressBackup -Type Full -EnableException -Initialize
            $logbackup = $primarydb | Backup-DbaDatabase -Checksum -CompressBackup -Type Log -EnableException -Initialize
            $allbackups[$db] = $fullbackup, $logbackup

            foreach ($file in $allbackups[$db]) {
                #Write-Output $file.Path
                $backupPath =  $file.Path -replace ':', '$'
                $primaryHost = $Primary.Name.Substring(0, $Primary.Name.IndexOf('\')+1)
                $secondaryHost = $second.Name.Substring(0, $second.Name.IndexOf('\')+1)

                $secondaryPath = '\\' + $secondaryHost + $backupPath
                $primaryPath = '\\' + $primaryHost + $backupPath
                #Write-Output $secondaryPath
                Write-Output $primaryPath

                Copy-Item -Path $primaryPath -Destination $secondaryPath
            }
        
            $allbackups[$db] | Restore-DbaDatabase -SqlInstance $second.Name -WithReplace -NoRecovery -EnableException
        
            #Check si la DB est déjà dans le groupe ou pas
            $agInDb = Get-DbaAgDatabase -SqlInstance $Instance -AvailabilityGroup $AG | Where-Object Name -eq $db.Name
            if (-not $agInDb) {
                Write-Output "not agInDb"
                $query = "ALTER AVAILABILITY GROUP [$($AG)] ADD DATABASE [$($db.Name)]" 
                Invoke-DbaQuery -SqlInstance $Instance -Query $query
            }
            Write-Output "set hadr"
            #Add-DbaAgDatabase -SqlInstance $second.Name -AvailabilityGroup $AG -Database $db.Name -Secondary
            $query = "ALTER DATABASE [$($db.Name)] SET HADR AVAILABILITY GROUP = [$($AG)]"
            Invoke-DbaQuery -SqlInstance $second.Name -Query $query

        } # if (-not $secondaryDb)

    } # foreach ($second in $secondaries)
}


