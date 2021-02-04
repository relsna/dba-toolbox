try {
    Get-Module -Name dbatools | Remove-Module
    Import-Module dbatools -MinimumVersion '1.0.135' -Force
} catch {
    Write-Warning 'dbatools module 1.0.135+ is mandatory. Exit...'
    exit
}

function Get-DbiDMKBackupDir {
    [Parameter(Mandatory=$true)]$InstanceName

    $backupDir = Invoke-DbaQuery -SqlInstance $InstanceName -Database dbi_tools -Query 'SELECT value from [maintenance].[dbi_maintenance_configuration] where parameter = @param' -SqlParameters @{ Param = "backupdir" }
    return $backupDir.value
}

function Add-DbiAgDatabase {
    
    param (
        [Parameter(Mandatory=$true)]$Listener
        , [Parameter(Mandatory=$false)]$DbOwner = "sa"
    )

    <#
        .SYNOPSIS
        Adds databases to AlwaysOn Availability Group
            - Automatic seeding if possible (version 2016+) or Manual seeding

        .DESCRIPTION
        Work In Progress
        Do not use in Prod

        Requires dbatools 1.0.135 minimum (Restore-DbaDatabase -ExecuteAs)

        Takes a Listener name as parameter.
            - Go to the primary replica the listener is currently on
            - For all databases that are not existing on any secondary replica
                - Backup database
                - Copy to secondary replica default backup folder
                - Restore database with norecovery
                - Add DB to the Availability Group related to the Listener in parameter
            
        To Do :
            - Not take new backup - Use existing backups - Get-DbaBackupHistory
            - Use dbi tools backup path
            - Check Free Disk Space before Backup & Restore ?

        .PARAMETER Listener
        Listener Name

        .EXAMPLE
        C:\PS> Add-DbiAgDatabase -Listener 'LST-APP-QUAL' -Verbose

        .LINK
        Online version: https://github.com/relsna/dba-toolbox/tree/main/PowerShell
    #>

    # To check if this is OK with multiple AG primary on this replica?
    $primaryReplica =    Get-DbaAgReplica -SqlInstance $listener | Select-Object -Unique | Where-Object Role -eq Primary
    $secondaryReplicas = Get-DbaAgReplica -SqlInstance $listener | Select-Object -Unique | Where-Object Role -eq Secondary
    
    # Get only the AG related to the listener. Exclude other AG on the instance
    $AG = (Get-DbaAgListener -SqlInstance $listener | Where-Object Name -eq $listener).AvailabilityGroup
    $databases = Get-DbaDatabase -SqlInstance $primaryReplica.Name -Status Normal
    $allbackups = @{}

    foreach ($db in $databases) {
        $primaryDb = Get-DbaDatabase -SqlInstance $primaryReplica.Name -Database $db.Name -Status Normal
        
        foreach ($second in $secondaryReplicas) {
            $secondaryDb = Get-DbaDatabase -SqlInstance $second.Name -Database $db.Name
            Write-Verbose "secondary:  $secondaryDb"

            if (-not $secondaryDb) {
                Write-Verbose $db.Name

                # Check if database is in FULL recovery Model
                if ($primaryDb.RecoveryModel -ne 'Full') {
                    $primaryDb | Set-DbaDbRecoveryModel -RecoveryModel Full -Confirm:$false
                }
                
                # Check Automatic seeding
                if (-not ($second.SeedingMode -eq 'Automatic' -and $second.ServerVersion.Major -ge 13)) {

                    # Get Backup Dir from dbi_tools database
                    <#
                    $DmkBackupPath = Get-DbiDMKBackupDir -InstanceName $primaryReplica.Name
                    if ($DmkBackupPath) {
                        $fullbackup = $primarydb | Backup-DbaDatabase -Path $DmkBackupPath -Checksum -CompressBackup -Type Full -EnableException -Initialize
                        $logbackup = $primarydb | Backup-DbaDatabase -Path $DmkBackupPath -Checksum -CompressBackup -Type Log -EnableException -Initialize
                    } else {
                        $fullbackup = $primarydb | Backup-DbaDatabase -Checksum -CompressBackup -Type Full -EnableException -Initialize
                        $logbackup = $primarydb | Backup-DbaDatabase -Checksum -CompressBackup -Type Log -EnableException -Initialize
                    }
                    #>
                    
                    $fullbackup = $primarydb | Backup-DbaDatabase -Checksum -CompressBackup -Type Full -EnableException -Initialize
                    $logbackup = $primarydb | Backup-DbaDatabase -Checksum -CompressBackup -Type Log -EnableException -Initialize
                    $allbackups[$db] = $fullbackup, $logbackup
                    <#
                    $allbackups[$db] = Get-DbaDbBackupHistory -SqlInstance $primaryReplica.Name -Database $primarydb.Name -IncludeCopyOnly -Last -EnableException
                    if ($allbackups[$db].Type -notcontains 'Full') {
                        $fullbackup = $primarydb | Backup-DbaDatabase -Checksum -CompressBackup -Type Full -EnableException -Initialize
                        $logbackup = $primarydb | Backup-DbaDatabase -Checksum -CompressBackup -Type Log -EnableException -Initialize
                        $allbackups[$db] = $fullbackup, $logbackup
                    }
                    if ($allbackups[$db].Type -notcontains 'Log') {
                        $logbackup = $primarydb | Backup-DbaDatabase -Checksum -CompressBackup -Type Log -EnableException -Initialize
                        $allbackups[$db] = $allbackups[$db], $logbackup
                    }
                    #>
                    
                    $primaryHost = $primaryReplica.Name.Substring(0, $primaryReplica.Name.IndexOf('\')+1)
                    $secondaryHost = $second.Name.Substring(0, $second.Name.IndexOf('\')+1)

                    foreach ($file in $allbackups[$db]) {
                        $backupPath =  $file.Path -replace ':', '$'
                        $secondaryPath = '\\' + $secondaryHost + $backupPath
                        $primaryPath = '\\' + $primaryHost + $backupPath
                        
                        Write-Verbose $primaryPath
                        Write-Verbose $secondaryPath

                        Copy-Item -Path $primaryPath -Destination $secondaryPath
                    }
                
                    $allbackups[$db] | Restore-DbaDatabase -SqlInstance $second.Name -ExecuteAS $DbOwner -WithReplace -NoRecovery -EnableException
                
                    # Check if DB is aready joined to AG
                    $agInDb = Get-DbaAgDatabase -SqlInstance $primaryReplica.Name -AvailabilityGroup $AG | Where-Object Name -eq $db.Name
                    if (-not $agInDb) {
                        Write-Verbose "not agInDb primary"
                        $query = "ALTER AVAILABILITY GROUP [$($AG)] ADD DATABASE [$($db.Name)]" 
                        Invoke-DbaQuery -SqlInstance $primaryReplica.Name -Query $query
                    }
                    $agInDb = Get-DbaAgDatabase -SqlInstance $second.Name -AvailabilityGroup $AG |Where-Object {($_.Name -eq $db.Name) -and ($_.IsJoined -eq $true) -and ($_.SynchronizationState -eq 'Synchronized')}
                    if (-not $agInDb) {
                        Write-Verbose "not agInDb secondary"
                        # Add-DbaAgDatabase -SqlInstance $second.Name -AvailabilityGroup $AG -Database $db.Name -Secondary
                        $query = "ALTER DATABASE [$($db.Name)] SET HADR AVAILABILITY GROUP = [$($AG)]"
                        Invoke-DbaQuery -SqlInstance $second.Name -Query $query
                    }
                    
                    # Delete files
                    foreach ($file in $allbackups[$db]) {
                        $backupPath =  $file.Path -replace ':', '$'
                        $secondaryPath = '\\' + $secondaryHost + $backupPath
                        $primaryPath = '\\' + $primaryHost + $backupPath

                        try {
                            Remove-Item $primaryPath -force
                        } catch {
                            Write-Verbose "Could not delete file ($primaryPath)"
                        }
    
                        try {
                            Remove-Item $secondaryPath -force
                        } catch {
                            Write-Verbose "Could not delete file ($primsecondaryPatharyPath)"
                        }
                    }

                } else {
                    Add-DbaAgDatabase -SqlInstance $primaryReplica.Name -AvailabilityGroup $AG -Database $db.Name -SeedingMode Automatic
                }
            }
        }
    }
}
