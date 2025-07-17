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

if ($inputURI -match '(?<Protocol>\w+)\:\/\/(?:(?<Username>[\w|\@|\.]+)@)?(?<HostAddress>.+)\:(?<Port>\d{2,5})') {
    $inputArguments.Add('Protocol', $Matches.Protocol)
    $inputArguments.Add('Username', $Matches.Username) # Optional
    $inputArguments.Add('Port', $Matches.Port)
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

$sshArguments = ''

if ($sshPreferredClient -eq 'openssh') {
    $appExec = Get-Command 'ssh.exe' | Select-Object -ExpandProperty 'Source'
    if (Test-Path $appExec) {
        $SSHClient = $appExec
    } else {
        Write-Warning 'Could not find ssh.exe in Path. Exiting...'
        Exit
    }
    
    if ($inputArguments.Username) {
        $sshArguments += "{0} -l {1} -p {2}" -f $inputArguments.HostAddress, $inputArguments.Username, $inputArguments.Port
    } else {
        $sshArguments += "{0} -p {1}" -f $inputArguments.HostAddress, $inputArguments.Port   
    }
    
    if ($sshVerbosity) {
        $sshArguments += " -v"
    }

    if ($sshConnectionTimeout) {
        $sshArguments += " -o ConnectTimeout={0}" -f $sshConnectionTimeout
    }
}

if ($sshPreferredClient -eq 'plink') || ($sshPreferredClient -eq 'putty') {
    $executableName = $sshPreferredClient + '.exe'
    $appExec = Get-Command $executableName | Select-Object -ExpandProperty 'Source'
    if (Test-Path $appExec) {
        $SSHClient = $appExec
    } else {
        Write-Warning 'Could not find {0} in Path. Exiting...' -f $executableName
        Exit
    }

    if ($inputArguments.Username) {
        $sshArguments += "{0} -l {1} -P {2}" -f $inputArguments.HostAddress, $inputArguments.Username, $inputArguments.Port
    } else {
        $sshArguments += "{0} -P {1}" -f $inputArguments.HostAddress, $inputArguments.Port   
    }

    if ($sshVerbosity) {
        $sshArguments += " -v"
    }
}

$sshCommand = $SSHClient + ' ' + $sshArguments

if ($sshPreferredClient -eq 'putty') {
	iex $sshCommand
} else {
	$wtArguments = ''
	
	if ($wtProfile) {
	    $wtArguments += "-p {0} " -f $wtProfile
	}
	
	$wtArguments += 'new-tab ' + $sshCommand
	
	#Write-Output "Start-Process Command: $windowsTerminal Arguments: $wtArguments"
	
	Start-Process -FilePath $windowsTerminal -ArgumentList $wtArguments
}