Function Get-OSArchitecture
{
	$OS = Get-WmiObject -Class Win32_OperatingSystem
	$Version = [Version]$OS.Version
	
	If($Version -ge [Version]"6.1")
	{
		If($OS.OSArchitecture -like "*64*"){ return "64-bit"}
		ElseIf ($OS.OSArchitecture -like "*32*"){ return "32-bit"}
		Else{ return $OS.OSArchitecture}
	}
	Else
	{
		If(${ENV:ProgramFiles(x86)})
		{
			return "64-bit"
		}
		Else
		{
			return "32-bit"
		}
	}
}

# ===============================================================================
$logPath = "${env:SystemRoot}\@MYPCMGT\LOGS"
$GUID_list = @()
$uninstalledGUID_list = @()


# ===============================================================================
$issDirItems = Get-ChildItem "C:\Program Files (x86)\InstallShield Installation Information"

foreach ($dirItem in $issDirItems) {

	$TargetGUID = $dirItem.name.ToUpper()
	$paths = @(
		"HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
		"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
	)

	foreach ($path in $paths) {

		$subkeys = Get-ChildItem $path
		foreach ($subkey in $subkeys) {
			
			$keyLeafname = (Split-Path $subkey -Leaf).ToUpper()
			$helplinkValue = Get-ChildItem "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" | Select-Object -Last 1 | Get-ItemProperty -Name "HelpLink"
			If ( ($keyLeafname -eq $TargetGUID) -and ($helplinkValue -like '*jmp.com*')) {
				$GUID_list += $dirItem.name
			}
		}
	}
}

foreach($appGuid in $GUID_list) {

$content = @"
[InstallShield Silent]
Version=v7.00
File=Response File
[File Transfer]
OverwrittenReadOnly=NoToAll
[${appGUID}-DlgOrder]
Dlg0=${appGUID}-MessageBox-0
Count=2
Dlg1=${appGUID}-SdFinish-0
[${appGUID}-MessageBox-0]
Result=6
[Application]
Name=JMP
Version=18.0
Company=JMP Statistical Discovery LLC
Lang=0409
[${appGUID}-SdFinish-0]
Result=1
bOpt1=0
bOpt2=0
"@
	$content | Set-Content -Path "$SourcesPath\silent.iss" -Force

	If (Get-OSArchitecture -like '*64*')
	{
		$programFiles_path = ${env:ProgramFiles(x86)}
	}
	Else
	{
		$programFiles_path = ${env:ProgramFiles}
	}

	$uninstallArgs = "-runfromtemp -l0x0409 -removeonly /s /f1`"${SourcesPath}\silent.iss`""


	$proc = Start-Process "${programFiles_path}\InstallShield Installation Information\${appGuid}\setup.exe" -ArgumentList $uninstallArgs -Wait -NoNewWindow

	If ($proc.ExitCode -ne 1)  {
		$uninstalledGUID_list += $appGuid
	}

	Remove-Item "${SourcesPath}\silent.iss" -Force

}

If (!Test-Path $logPath) {
	New-Item $logPath -ItemType Directory
}
$uninstalledGUID_list | Set-Content "$logPath\JMPUNINSTALLER.log"
