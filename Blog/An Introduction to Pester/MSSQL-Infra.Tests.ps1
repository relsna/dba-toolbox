
$SQLDisk = 'S:'
$SQLInstance = 'localhost\INST1'

Describe "Power Plan" {
    $PowerPlan = (Get-CimInstance -ClassName 'Win32_PowerPlan' -Namespace 'root\cimv2\power' | Where-Object IsActive).ElementName
    It "Should be set to High Performance" {
        $PowerPlan | Should -be "High Performance" -Because "This Power Plan increases performance at the cost of high energy consumption"
    }
}

Describe "Disk Optimization" {
    Context "File Allocation Unit Size" {    
        $BlockSize = (Get-CimInstance -ClassName Win32_Volume | Where-Object DriveLetter -eq $SQLDisk).BlockSize
        It "Should be 64 KB" {
            $BlockSize | Should -Be 65536 -Because "It is recommended to set a File Allocation Unit Size value to 64 KB on partitions where resides SQL Server data or log files"
        }
    }
    Context "Search Indexing" {    
        $Indexing = (Get-CimInstance -ClassName Win32_Volume | Where-Object DriveLetter -eq $SQLDisk).IndexingEnabled
        It "Should be Disabled" {
            $Indexing | Should -BeFalse -Because "It is recommended to disable 'Allow files on this drive to have contents indexed' in disk option, for SQL Server drives. For performance reason, especially when Filestream feature is used"
        }
    }
}

Describe "SQL Server Best Practices" {
    Context "SQL Server Error Log Files" {
        $errorLogCount = (Get-DbaErrorLogConfig -SqlInstance $SQLInstance).LogCount
        It "Should have Number of Log files set to 30" {
            $errorLogCount | Should -Be 30 -Because "Best practices requires 30 logs files to perform daily recycling"
        }
    }
}
