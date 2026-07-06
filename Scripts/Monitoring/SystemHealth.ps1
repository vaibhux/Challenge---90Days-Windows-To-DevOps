#==========================================
# Enterprise Windows Health Report
# Author : Vaibhavi Channe
#==========================================

$Computer = $env:COMPUTERNAME
$Date = Get-Date -Format "yyyy-MM-dd_HH-mm"

$Report = "C:\Reports"

if (!(Test-Path $Report))
{
    New-Item -ItemType Directory -Path $Report | Out-Null
}

$ReportFile = "$Report\SystemHealthReport_$Computer`_$Date.html"

####################################################
# System Information
####################################################

$OS = Get-CimInstance Win32_OperatingSystem

$CPU = Get-CimInstance Win32_Processor

$MemoryTotal = [math]::Round($OS.TotalVisibleMemorySize/1MB,2)

$MemoryFree = [math]::Round($OS.FreePhysicalMemory/1MB,2)

$MemoryUsed = [math]::Round($MemoryTotal-$MemoryFree,2)

$MemoryPercent = [math]::Round(($MemoryUsed/$MemoryTotal)*100,2)

####################################################
# Disk Information
####################################################

$Disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
ForEach-Object{

$Used = [math]::Round((($_.Size-$_.FreeSpace)/$_.Size)*100,2)

[PSCustomObject]@{

Drive=$_.DeviceID

SizeGB=[math]::Round($_.Size/1GB,2)

FreeGB=[math]::Round($_.FreeSpace/1GB,2)

UsedPercent=$Used

Status=if($Used -gt 90){"CRITICAL"}else{"Healthy"}

}

}

####################################################
# Top CPU Processes
####################################################

$CPUProcess=Get-Process |
Sort CPU -Descending |
Select -First 10 ProcessName,Id,CPU

####################################################
# Top Memory Processes
####################################################

$MemoryProcess=Get-Process |
Sort WorkingSet64 -Descending |
Select -First 10 ProcessName,Id,
@{N="Memory(MB)";E={[math]::Round($_.WorkingSet64/1MB,2)}}

####################################################
# Running Services
####################################################

$RunningServices=(Get-Service |
Where Status -eq Running).Count

####################################################
# Automatic Services Not Running
####################################################

$StoppedAuto=Get-CimInstance Win32_Service |
Where{

$_.StartMode -eq "Auto" -and

$_.State -ne "Running"

} |
Select Name,DisplayName,State

####################################################
# Last 20 Errors
####################################################

$Errors=Get-WinEvent -FilterHashtable @{

LogName="System"

Level=2

} -MaxEvents 20 |
Select TimeCreated,Id,ProviderName,Message

####################################################
# Failed Logins
####################################################

$FailedLogons=Get-WinEvent -FilterHashtable @{

LogName="Security"

ID=4625

} -MaxEvents 10 |
Select TimeCreated,Id,Message

####################################################
# Last Boot Time
####################################################

$Boot=$OS.LastBootUpTime

####################################################
# HTML
####################################################

$html=@"

<html>

<head>

<title>System Health Report</title>

<style>

body{

font-family:Segoe UI;

background:#F4F4F4;

}

table{

border-collapse:collapse;

width:100%;

}

th{

background:#2F5597;

color:white;

padding:8px;

}

td{

padding:6px;

border:1px solid gray;

}

h1{

color:#2F5597;

}

.good{

color:green;

font-weight:bold;

}

.bad{

color:red;

font-weight:bold;

}

</style>

</head>

<body>

<h1>Windows Server Health Report</h1>

<h3>Computer : $Computer</h3>

<h3>Date : $(Get-Date)</h3>

<hr>

<h2>Operating System</h2>

$($OS |
Select Caption,Version,BuildNumber |
ConvertTo-Html -Fragment)

<h2>CPU</h2>

$($CPU |
Select Name,NumberOfCores,NumberOfLogicalProcessors |
ConvertTo-Html -Fragment)

<h2>Memory</h2>

<table>

<tr>

<th>Total GB</th>

<th>Used GB</th>

<th>Free GB</th>

<th>Usage %</th>

</tr>

<tr>

<td>$MemoryTotal</td>

<td>$MemoryUsed</td>

<td>$MemoryFree</td>

<td>$MemoryPercent</td>

</tr>

</table>

<h2>Disk Usage</h2>

$($Disks | ConvertTo-Html -Fragment)

<h2>Running Services</h2>

<h3>$RunningServices</h3>

<h2>Stopped Automatic Services</h2>

$($StoppedAuto | ConvertTo-Html -Fragment)

<h2>Top CPU Processes</h2>

$($CPUProcess | ConvertTo-Html -Fragment)

<h2>Top Memory Processes</h2>

$($MemoryProcess | ConvertTo-Html -Fragment)

<h2>Last Boot Time</h2>

<h3>$Boot</h3>

<h2>Last 20 System Errors</h2>

$($Errors | ConvertTo-Html -Fragment)

<h2>Failed Login Attempts</h2>

$($FailedLogons | ConvertTo-Html -Fragment)

</body>

</html>

"@

$html | Out-File $ReportFile

Invoke-Item $ReportFile

Write-Host ""

Write-Host "==========================================" -ForegroundColor Green

Write-Host "Report Generated Successfully"

Write-Host ""

Write-Host $ReportFile -ForegroundColor Yellow

Write-Host "=========================================="
