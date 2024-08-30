#PcP#

$PSPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$SourcesPath = Join-Path $PSPath "Sources"

# import PMIDeployer module
If (-not (Get-Module -Name PMIDeployer))
{
	$PMIModuleFilePath = Join-Path "$PSPath\Modules" "PMIDeployer.psm1"
	Import-Module $PMIModuleFilePath -ErrorAction Stop
	$PMIModulePURDS = Join-Path "$PSPath\Modules" "PURDS.psm1"
   	Import-Module $PMIModulePURDS -ErrorAction Stop
}

# ===============================================================================
$GUID_list = @()
$uninstalledGUID_list = @()


$issDirItems = Get-ChildItem "C:\Program Files (x86)\InstallShield Installation Information"

foreach ($dirItem in $issDirItems) {

	$TargetGUID = ($dirItem.name).ToUpper()
	$paths = @(
		"HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
		"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
	)

	foreach ($path in $paths) {

		$subkeys = Get-ChildItem $path
		foreach ($subkey in $subkeys) {
			
			$keyLeafname = (Split-Path $subkey -Leaf).ToUpper()
			$displayName = $subkey | Get-ItemProperty -Name "DisplayName" -ErrorAction SilentlyContinue
			If ( ($keyLeafname -eq $TargetGUID) -and ($displayName) -and ($displayName.DisplayName -like '*JMP*') ) {
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

$logPath = "${env:SystemRoot}\@MYPCMGT\LOGS"
If ( !(Test-Path $logPath) ) {
	New-Item $logPath -ItemType Directory
}
$uninstalledGUID_list | Set-Content "$logPath\JMPUNINSTALLER.log"
