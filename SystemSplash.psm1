# Microsoft Windows Powershell Module Script
#
# Name: SystemSplash Module
# Version: 0.1.0.0
# Date: 2020-01-25
# Author: Roman Gelman
# Author: MMillar
# https://github.com/mmillar-bolis
# http://www.bolis.com
#
# Description:
# An ascii system information display for PowerShell.
#
# License: 
# The MIT License (MIT, Expat)
#

# A function by the fabulous Roman Gelman to write fancy percentage bar
# graphics to the console host.
<#
.SYNOPSIS
	Create percentage bar.
.DESCRIPTION
	This cmdlet creates percentage bar.
.PARAMETER Percent
	Value in percents (%).
.PARAMETER Value
	Value in arbitrary units.
.PARAMETER MaxValue
	100% value.
.PARAMETER BarLength
	Bar length in chars.
.PARAMETER BarView
	Different char sets to build the bar.
.PARAMETER GreenBorder
	Percent value to change bar color from green to yellow (relevant with -DrawBar parameter only).
.PARAMETER YellowBorder
	Percent value to change bar color from yellow to red (relevant with -DrawBar parameter only).
.PARAMETER NoPercent
	Exclude percentage number from the bar.
.PARAMETER DrawBar
	Directly draw the colored bar onto the PowerShell console (unsuitable for calculated properties).
.EXAMPLE
	PS C:\> New-PercentageBar -Percent 90 -DrawBar
	Draw single bar with all default settings.
.EXAMPLE
	PS C:\> New-PercentageBar -Percent 95 -DrawBar -GreenBorder 70 -YellowBorder 90
	Draw the bar and move the both color change borders.
.EXAMPLE
	PS C:\> 85 |New-PercentageBar -DrawBar -NoPercent
	Pipeline the percent value to the function and exclude percent number from the bar.
.EXAMPLE
	PS C:\> For ($i=0; $i -le 100; $i+=10) {New-PercentageBar -Percent $i -DrawBar -Length 100 -BarView AdvancedThin2; "`r"}
	Demonstrates advanced bar view with custom bar length and different percent values.
.EXAMPLE
	PS C:\> $Folder = 'C:\reports\'
	PS C:\> $FolderSize = (Get-ChildItem -Path $Folder |measure -Property Length -Sum).Sum
	PS C:\> Get-ChildItem -Path $Folder -File |sort Length -Descending |select -First 10 |select Name,Length,@{N='SizeBar';E={New-PercentageBar -Value $_.Length -MaxValue $FolderSize}} |ft -au
	Get file size report and add calculated property 'SizeBar' that contains the percent of each file size from the folder size.
.EXAMPLE
	PS C:\> $VolumeC = gwmi Win32_LogicalDisk |? {$_.DeviceID -eq 'c:'}
	PS C:\> Write-Host -NoNewline "Volume C Usage:" -ForegroundColor Yellow; `
	PS C:\> New-PercentageBar -Value ($VolumeC.Size-$VolumeC.Freespace) -MaxValue $VolumeC.Size -DrawBar; "`r"
	Get system volume usage report.
.NOTES
	Author       ::	Roman Gelman.
	Version 1.0  ::	04-Jul-2016  :: Release.
.LINK
	http://ps1code.com
#>
function script:New-PercentageBar {
	[CmdletBinding(DefaultParameterSetName='PERCENT')]
	param (
		[Parameter(
			Position=1,
			Mandatory=$true,
			ValueFromPipeline,
			ParameterSetName='PERCENT'
		)]
		[ValidateRange(0,100)]
		[int]$Percent,
		[Parameter(
			Position=1,
			Mandatory=$true,
			ValueFromPipeline,
			ParameterSetName='VALUE'
		)]
		[ValidateRange(0,[double]::MaxValue)]
		[double]$Value,
		[Parameter(
			Position=2,
			Mandatory=$true,
			ParameterSetName='VALUE'
		)]
		[ValidateRange(1,[double]::MaxValue)]
		[double]$MaxValue,
		[Parameter(
			Position=3,
			Mandatory=$false
		)]
		[Alias("BarSize","Length")]
		[ValidateRange(10,100)]
		[int]$BarLength = 10,
		[Parameter(
			Position=4,
			Mandatory=$false
		)]
		[ValidateSet(
			"SimpleThin",
			"SimpleThick1",
			"SimpleThick2",
			"AdvancedThin1",
			"AdvancedThin2",
			"AdvancedThick"
		)]
		[string]$BarView = "SimpleThin",
		[Parameter(
			Position=5,
			Mandatory=$false
		)]
		[ValidateRange(50,80)]
		[int]$GreenBorder = 60,
		[Parameter(
			Position=6,
			Mandatory=$false
		)]
		[ValidateRange(80,90)]
		[int]$YellowBorder = 80,
		[Parameter(Mandatory=$false)]
		[switch]$NoPercent,
		[Parameter(Mandatory=$false)]
		[switch]$DrawBar
	)
	begin {
		if ($PSBoundParameters.ContainsKey('VALUE')) {
			if ($Value -gt $MaxValue) {
				throw "The [-Value] parameter cannot be greater than [-MaxValue]!"
			} else {
				$Percent = $Value/$MaxValue*100 -as [int]
			}
		}

		if ($YellowBorder -le $GreenBorder) {
			throw "The [-YellowBorder] value must be greater than [-GreenBorder]!"
		}

		function Set-BarView ($View) {
			Switch -exact ($View) {
				"SimpleThin" {
					$GreenChar = [char]9632
					$YellowChar = [char]9632
					$RedChar = [char]9632
					$EmptyChar = "-"
					Break
				}
				"SimpleThick1" {
					$GreenChar = [char]9608
					$YellowChar = [char]9608
					$RedChar = [char]9608
					$EmptyChar = "-"
					Break
				}
				"SimpleThick2" {
					$GreenChar = [char]9612
					$YellowChar = [char]9612
					$RedChar = [char]9612
					$EmptyChar = "-"
					Break
				}
				"AdvancedThin1"	{
					$GreenChar = [char]9632
					$YellowChar = [char]9632
					$RedChar = [char]9632
					$EmptyChar = [char]9476
					Break
				}
				"AdvancedThin2" {$GreenChar = [char]9642
					$YellowChar = [char]9642
					$RedChar = [char]9642
					$EmptyChar = [char]9643
					Break
				}
				"AdvancedThick"	{
					$GreenChar = [char]9617
					$YellowChar = [char]9618
					$RedChar = [char]9619
					$EmptyChar = [char]9482
					Break
				}
			}
			$Properties = [ordered]@{
				Char1 = $GreenChar
				Char2 = $YellowChar
				Char3 = $RedChar
				Char4 = $EmptyChar
			}
			$Object = New-Object PSObject -Property $Properties
			$Object
		} #End Function Set-BarView

		$BarChars = Set-BarView -View $BarView
		$Bar = $null

		function Draw-Bar {
			param (
				[Parameter(Mandatory=$true)]
				[string]$Char,
				[Parameter(Mandatory=$false)]
				[string]$Color = 'White',
				[Parameter(Mandatory=$false)]
				[boolean]$Draw
			)

			if ($Draw) {
				Write-Host -NoNewline -ForegroundColor ([System.ConsoleColor]$Color) $Char
			} else {
				return $Char
			}
		} #End Function Draw-Bar
	} #End Begin
	process {
		if ($NoPercent) {
			$Bar += Draw-Bar -Char "[ " -Draw $DrawBar
		} else {
			if ($Percent -eq 100) {
				$Bar += Draw-Bar -Char "$Percent% [ " -Draw $DrawBar
			} elseIf ($Percent -ge 10) {
				$Bar += Draw-Bar -Char " $Percent% [ " -Draw $DrawBar
			} else {
				$Bar += Draw-Bar -Char "  $Percent% [ " -Draw $DrawBar
			}
		}
	
		for ($i=1; $i -le ($BarValue = ([Math]::Round($Percent * $BarLength / 100))); $i++) {
			if ($i -le ($GreenBorder * $BarLength / 100)) {
				$Bar += Draw-Bar -Char ($BarChars.Char1) -Color 'DarkGreen' -Draw $DrawBar
			} elseIf ($i -le ($YellowBorder * $BarLength / 100)) {
				$Bar += Draw-Bar -Char ($BarChars.Char2) -Color 'Yellow' -Draw $DrawBar
			} else {
				$Bar += Draw-Bar -Char ($BarChars.Char3) -Color 'Red' -Draw $DrawBar
			}
		}

		for ($i=1; $i -le ($EmptyValue = $BarLength - $BarValue); $i++) {
			$Bar += Draw-Bar -Char ($BarChars.Char4) -Draw $DrawBar
		}

		$Bar += Draw-Bar -Char " ]" -Draw $DrawBar
	} #End Process
	end {
		if (!$DrawBar) {
			return $Bar
		}
	} #End End
} #EndFunction New-PercentageBar

# May need later for multiplatform and back-compat support.
#function script:Set-Platform {
#	if ( $PSVersionTable.PSVersion.Major -lt 6 -And [Environment]::OSVersion.Platform -eq 'Win32NT' ) {
#		$global:PlatformHash = @{
#			IsCoreCLR = $false
#			IsWindows = $true
#			IsLinux = $false
#			IsMacOS = $false
#		}
#	}
#}

<#
.NAME
    Get-SystemSplash
.SYNOPSIS
    Displays system information to a host.
.DESCRIPTION
    The Get-SystemSplash cmdlet is a system information tool written in PowerShell.
.PARAMETER ComputerName
	The name of the target computer.
.PARAMETER Credential
	The name of the user on the target computer.
.PARAMETER Graph
	Display graphs instead of numeric disk and ram values.
.EXAMPLE
	PS C:\> Get-SystemSplash -ComputerName <COMPUTER> -Credential <USER>
	Display system information from the specified computer and user names.
.NOTES
	Author       ::	MMillar
	Author       ::	Roman Gelman
#>
function Get-SystemSplash {
	[CmdletBinding()]
	param(
		[Parameter(
			Position=0,
			Mandatory=$false
		)]
		[ValidateNotNullOrEmpty()]
		[string[]]$ComputerName,

		[Parameter(
			Position=1,
			Mandatory=$false
		)]
		[PSCredential]
		[System.Management.Automation.CredentialAttribute()]$Credential,

		[Parameter(Mandatory=$false)]
		[switch]$Graph
    )
	begin {
		if (-Not $Graph) {
			$Graph = $false
		}
		if (-Not $ComputerName) {
			$RemoteSession = $null
		}

		#Define ScriptBlock for data collection
		$ScriptBlock = {
			$Local_System_Info = Get-CimInstance -ClassName Win32_OperatingSystem
			$Local_System_Volume = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object -Property DeviceID -eq $Local_System_Info.SystemDrive
			$Local_System_Processor = Get-CimInstance -ClassName Win32_Processor
			if (([System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()).DomainName) {
				$DomainName = ([System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()).DomainName
			} else {
				$DomainName = (Get-CimInstance -ClassName Win32_ComputerSystem).Domain
			}

			[pscustomobject]@{
				Operating_System = $Local_System_Info
				Processor = $Local_System_Processor
				Process_Count = (Get-CimInstance -ClassName Win32_Process).Count
				Shell_Info = ("{0}.{1}" -f $PSVersionTable.PSVersion.Major,$PSVersionTable.PSVersion.Minor)
				Root_Volume = $Local_System_Volume
				User = "${DomainName}\${env:UserName}"
				Date = Get-Date
				Kernel = (Get-ItemProperty -Path "${env:SystemRoot}\System32\ntoskrnl.exe").VersionInfo.FileVersion
			}
		}
	} #End Begin
	process {
		if ($ComputerName) {
			if ("$ComputerName" -ne "$env:ComputerName") {
				# Build Hash to be used for passing parameters to 
				# New-PSSession commandlet
				$PSSessionParams = @{
					ComputerName = $ComputerName
					ErrorAction = 'Stop'
				}

				# Add optional parameters to hash
				if ($Credential) {
					$PSSessionParams.Add('Credential', $Credential)
				}

				# Create remote powershell session   
				try {
					$RemoteSession = New-PSSession @PSSessionParams
				}
				catch {
					throw $_.Exception.Message
				}
			} else {
				$RemoteSession = $null
			}
		}

		# Build Hash to be used for passing parameters to 
		# Invoke-Command commandlet
		$CommandParams = @{
			ScriptBlock = $ScriptBlock
			ErrorAction = 'Stop'
		}

		# Add optional parameters to hash
		if ($RemoteSession) {
			$CommandParams.Add('Session', $RemoteSession)
		}

		# Run ScriptBlock    
		try {
			$ReturnedValues = Invoke-Command @CommandParams
		} catch {
			if ($RemoteSession) {
				Remove-PSSession $RemoteSession
			}
			throw $_.Exception.Message
		}

		# Assign variables
		$Date = ($ReturnedValues.Date).ToString('yyyy-MM-dd HH:mm:ss')
		$User = $ReturnedValues.User
		$Computer_Name = $ReturnedValues.Operating_System.CSName
		$OS_Name = $ReturnedValues.Operating_System.Caption
		$Kernel_Info = 'NT ' + $ReturnedValues.Kernel + $ReturnedValues.Operating_System.OSArchitecture -replace '\([^\)]+\)',''
		$Process_Count = $ReturnedValues.Process_Count
		$Uptime = "$(($GetUptime = $($ReturnedValues.Date) - $($ReturnedValues.Operating_System.LastBootUpTime)).Days) days, $($GetUptime.Hours) hours, $($GetUptime.Minutes) minutes"
		$Shell_Info = 'PowerShell ' + $ReturnedValues.Shell_Info
		$CPU_Info = $ReturnedValues.Processor.Name -replace '\(C\)','' -replace '\(R\)','' -replace '\(TM\)','' -replace 'CPU','' -replace '\s+',' '
		$Current_Load = $ReturnedValues.Processor.LoadPercentage    
		$Memory_Size = "{0} MB/{1} MB " -f (([math]::round($ReturnedValues.Operating_System.TotalVisibleMemorySize/1KB))-([math]::round($ReturnedValues.Operating_System.FreePhysicalMemory/1KB))),([math]::round($ReturnedValues.Operating_System.TotalVisibleMemorySize/1KB))
		$Disk_Size = "{0} GB/{1} GB" -f (([math]::round($ReturnedValues.Root_Volume.Size/1GB)-[math]::round($ReturnedValues.Root_Volume.FreeSpace/1GB))),([math]::round($ReturnedValues.Root_Volume.Size/1GB))

		# Write to the Console
		Write-Host -Object ("")
		Write-Host -Object ("")
		Write-Host -Object ("         ,.=:^!^!t3Z3z.,                  ") -ForegroundColor Red
		Write-Host -Object ("        :tt:::tt333EE3                    ") -ForegroundColor Red
		Write-Host -Object ("        Et:::ztt33EEE ") -NoNewline -ForegroundColor Red
		Write-Host -Object (" @Ee.,      ..,     ${Date}") -ForegroundColor Green
		Write-Host -Object ("       ;tt:::tt333EE7") -NoNewline -ForegroundColor Red
		Write-Host -Object (" ;EEEEEEttttt33#     ") -ForegroundColor Green
		Write-Host -Object ("      :Et:::zt333EEQ.") -NoNewline -ForegroundColor Red
		Write-Host -Object (" SEEEEEttttt33QL     ") -NoNewline -ForegroundColor Green
		Write-Host -Object ("User: ") -NoNewline -ForegroundColor Red
		Write-Host -Object ("${User}") -ForegroundColor Cyan
		Write-Host -Object ("      it::::tt333EEF") -NoNewline -ForegroundColor Red
		Write-Host -Object (" @EEEEEEttttt33F      ") -NoNewline -ForeGroundColor Green
		Write-Host -Object ("Hostname: ") -NoNewline -ForegroundColor Red
		Write-Host -Object ("${Computer_Name}") -ForegroundColor Cyan
		Write-Host -Object ("     ;3=*^``````'*4EEV") -NoNewline -ForegroundColor Red
		Write-Host -Object (" :EEEEEEttttt33@.      ") -NoNewline -ForegroundColor Green
		Write-Host -Object ("OS: ") -NoNewline -ForegroundColor Red
		Write-Host -Object ("${OS_Name}") -ForegroundColor Cyan
		Write-Host -Object ("     ,.=::::it=., ") -NoNewline -ForegroundColor Cyan
		Write-Host -Object ("``") -NoNewline -ForegroundColor Red
		Write-Host -Object (" @EEEEEEtttz33QF       ") -NoNewline -ForegroundColor Green
		Write-Host -Object ("Kernel: ") -NoNewline -ForegroundColor Red
		Write-Host -Object ("${Kernel_Info}") -ForegroundColor Cyan
		Write-Host -Object ("    ;::::::::zt33) ") -NoNewline -ForegroundColor Cyan
		Write-Host -Object ("  '4EEEtttji3P*        ") -NoNewline -ForegroundColor Green
		Write-Host -Object ("Uptime: ") -NoNewline -ForegroundColor Red
		Write-Host -Object ("${Uptime}") -ForegroundColor Cyan
		Write-Host -Object ("   :t::::::::tt33.") -NoNewline -ForegroundColor Cyan
		Write-Host -Object (":Z3z.. ") -NoNewline -ForegroundColor Yellow
		Write-Host -Object (" ````") -NoNewline -ForegroundColor Green
		Write-Host -Object (" ,..g.        ") -NoNewline -ForegroundColor Yellow
		Write-Host -Object ("Shell: ") -NoNewline -ForegroundColor Red
		Write-Host -Object ("${Shell_Info}") -ForegroundColor Cyan
		Write-Host -Object ("   i::::::::zt33F") -NoNewline -ForegroundColor Cyan
		Write-Host -Object (" AEEEtttt::::ztF         ") -NoNewline -ForegroundColor Yellow
		Write-Host -Object ("CPU: ") -NoNewline -ForegroundColor Red
		Write-Host -Object ("${CPU_Info}") -ForegroundColor Cyan
		Write-Host -Object ("  ;:::::::::t33V") -NoNewline -ForegroundColor Cyan
		Write-Host -Object (" ;EEEttttt::::t3          ") -NoNewline -ForegroundColor Yellow
		Write-Host -Object ("Processes: ") -NoNewline -ForegroundColor Red
		Write-Host -Object ("${Process_Count}") -ForegroundColor Cyan
		Write-Host -Object ("  E::::::::zt33L") -NoNewline -ForegroundColor Cyan
		Write-Host -Object (" @EEEtttt::::z3F          ") -NoNewline -ForegroundColor Yellow
		Write-Host -Object ("Current Load: ") -NoNewline -ForegroundColor Red
		if ($Graph -eq $true) {
			Write-Host -Object (" ") -NoNewLine
			New-PercentageBar -DrawBar -Value ($ReturnedValues.Processor.LoadPercentage) -MaxValue (100); "`r"
		} else {
			Write-Host -Object ("${Current_Load}%") -ForegroundColor Cyan
		}
		Write-Host -Object (" {3=*^``````'*4E3)") -NoNewline -ForegroundColor Cyan
		Write-Host -Object (" ;EEEtttt:::::tZ``          ") -NoNewline -ForegroundColor Yellow
		Write-Host -Object ("Memory: ") -NoNewline -ForegroundColor Red
		if ($Graph -eq $true) {
			Write-Host -Object ("       ") -NoNewLine
			New-PercentageBar -DrawBar -Value (([math]::round($ReturnedValues.Operating_System.TotalVisibleMemorySize/1KB))-([math]::round($ReturnedValues.Operating_System.FreePhysicalMemory/1KB))) -MaxValue ([math]::round($ReturnedValues.Operating_System.TotalVisibleMemorySize/1KB)); "`r"
		} else {
			Write-Host -Object ("${Memory_Size}") -ForegroundColor Cyan
		}
		Write-Host -Object ("             ``") -NoNewline -ForegroundColor Cyan
		Write-Host -Object (" :EEEEtttt::::z7            ") -NoNewline -ForegroundColor Yellow
		Write-Host -Object ("System Volume: ") -NoNewline -ForegroundColor Red
		if ($Graph -eq $true) {
			New-PercentageBar -DrawBar -Value (([math]::round($ReturnedValues.Root_Volume.Size/1GB)-[math]::round($ReturnedValues.Root_Volume.FreeSpace/1GB))) -MaxValue (([math]::round($ReturnedValues.Root_Volume.Size/1GB))); "`r"
		} else {
			Write-Host -Object ("${Disk_Size}") -ForegroundColor Cyan
		}
		Write-Host -Object ("                 'VEzjt:;;z>*``           ") -ForegroundColor Yellow
		Write-Host -Object ("                      ````                  ") -ForegroundColor Yellow
		Write-Host -Object ("")
	}
    end {
		if ($RemoteSession) {
			Remove-PSSession $RemoteSession
		}
	}
}
