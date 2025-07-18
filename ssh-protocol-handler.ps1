# Copyright (c) Peet van de Sande. All rights reserved.
# Licensed under the MIT License.
#

# --> Begin user modifiable variables

# Set the SSH Client you would like to call
# Options: <openssh|plink|putty>
# Default: putty
$sshPreferredClient = 'putty'

# Set if you would like to see verbose output from the SSH Clients (Debug)
# Default: false
$sshVerbosity = $false

# Set the time OpenSSH will wait for connection in seconds before timing out
# Default: <emptystring> - We will let OpenSSH decide based on the system TCP timeout
# NOTE: Applies to OpenSSH only
$sshConnectionTimeout = 3

# Set the profile Windows Terminal will use as a base
# Default: <emtpystring> - We will let Windows Terminal decide based on it's default profile
$wtProfile = ''

# <-- End user modifiable variables

$inputURI = $args[0]
$inputArguments = @{}

if ($inputURI -match '(?<Protocol>\w+)://(?:(?<Username>[\w@\.\|]+)@)?(?<HostAddress>[^:]+)(?:\:(?<Port>\d{2,5}))?') {
	$inputArguments.Add('Protocol', $Matches.Protocol)
	$inputArguments.Add('Username', $Matches.Username) # Optional
	$inputArguments.Add('Port', $Matches.Port) # Optional
	$rawHost = $Matches.HostAddress

	switch -Regex ($rawHost) {
	   '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' {
			# Basic test for IP Address 
			$inputArguments.Add('HostAddress', $rawHost)
			Break
		}
	   '(?=^.{4,253}$)(^((?!-)[a-zA-Z0-9-]{0,62}[a-zA-Z0-9]\.)+[a-zA-Z]{2,63}$)' { 
			# Test for a valid Hostname
			$inputArguments.Add('HostAddress', $rawHost)
			Break
		}
		Default {
			Write-Warning 'The Hostname/IP Address passed is invalid. Exiting...'
			Exit
		}
	}
} else {
	Write-Warning 'The URL passed to the handler script is invalid. Exiting...'
	Exit
}

$executableName = ''
# Only verify Windows Terminal if we are using OpenSSH or Plink
if ($sshPreferredClient -eq 'openssh' -or $sshPreferredClient -eq 'plink') {
	$windowsTerminalStatus = Get-AppxPackage -Name 'Microsoft.WindowsTerminal*' | Select-Object -ExpandProperty 'Status'
	if ($windowsTerminalStatus -eq 'Ok') {
		$appExec = Get-Command 'wt.exe' | Select-Object -ExpandProperty 'Source'
		if (Test-Path $appExec) {
			$windowsTerminal = $appExec
		} else {
			Write-Warning 'Could not verify Windows Terminal executable path. Exiting...'
			Exit
		}
	} else {
		Write-Warning 'Windows Terminal is not installed. Exiting...'
		Exit
	}
}

$sshArguments = ''
if ($inputArguments.Username) {
	$sshArguments += " -l {0}" -f $inputArguments.Username
}

if ($sshPreferredClient -eq 'openssh') {
	$executableName = 'ssh.exe'
	if ($inputArguments.Port -and $inputArguments.Port -ne 22) {
		$sshArguments += " -p {0}" -f $inputArguments.Port
	}

	 if ($sshConnectionTimeout) {
		$sshArguments += " -o ConnectTimeout={0}" -f $sshConnectionTimeout
	}
}

if ($sshPreferredClient -eq 'plink' -or $sshPreferredClient -eq 'putty') {
	$executableName = $sshPreferredClient + '.exe'
	if ($inputArguments.Port -and $inputArguments.Port -ne 22) {
		$sshArguments += " -P {0}" -f $inputArguments.Port
	}
}

if ($sshVerbosity) {
	$sshArguments += " -v"
}

$appExec = Get-Command $executableName | Select-Object -ExpandProperty 'Source'
if (Test-Path $appExec) {
	$SSHClient = $appExec
} else {
	Write-Warning 'Could not find {0} in Path. Exiting...' -f $executableName
	Exit
}

if ($sshPreferredClient -eq 'putty') {
	$sshCommand = "{0} {1} {2}" -f $executableName, $sshArguments, $inputArguments.HostAddress
	iex $sshCommand
} else {
	$sshCommand = "{0} {1} {2}" -f $SSHClient, $sshArguments, $inputArguments.HostAddress
	$wtArguments = ''

	if ($wtProfile) {
		$wtArguments += "-p {0} " -f $wtProfile
	}

	$wtArguments += 'new-tab ' + $sshCommand

	#Write-Output "Start-Process Command: $windowsTerminal Arguments: $wtArguments"

	Start-Process -FilePath $windowsTerminal -ArgumentList $wtArguments
}
