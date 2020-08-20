# Switch network connection to private mode
# Required for WinRM firewall rules
$profile = Get-NetConnectionProfile
Set-NetConnectionProfile -Name $profile.Name -NetworkCategory Private

<#
.Synopsis
    Enables WinRM over https
.Description
    This cmdlet enables the WinRM endpoint using https and basic auth. This creates
    a self signed cert so you'll need to ensure your client ignores cert validation
    errors.
#>
function Enable-WinRM {
    # Ensure the Windows firewall allows WinRM https traffic over port 5986
    New-NetFirewallRule -Name "WINRM-HTTPS-In-TCP" `
        -DisplayName "Windows Remote Management (HTTPS-In)" `
        -Description "Inbound rule for Windows Remote Management via WS-Management. [TCP 5986]" `
        -Group "Windows Remote Management" `
        -Program "System" `
        -Protocol TCP `
        -LocalPort "5986" `
        -Action Allow `
        -Profile Domain,Private

    New-NetFirewallRule -Name "WINRM-HTTPS-In-TCP-PUBLIC" `
        -DisplayName "Windows Remote Management (HTTPS-In)" `
        -Description "Inbound rule for Windows Remote Management via WS-Management. [TCP 5986]" `
        -Group "Windows Remote Management" `
        -Program "System" `
        -Protocol TCP `
        -LocalPort "5986" `
        -Action Allow `
        -Profile Public

    Enable-WinRMConfiguration

    # Create self signed cert for TLS connections to WinRM
    $cert = New-SelfSignedCertificate -CertstoreLocation Cert:\LocalMachine\My -DnsName $env:COMPUTERNAME
    New-Item -Path WSMan:\LocalHost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $cert.Thumbprint -Force

    # Enable basic auth over https
    winrm set winrm/config/service '@{AllowUnencrypted="false"}'
    winrm set winrm/config/service/auth '@{Basic="true"}'
    winrm set 'winrm/config/listener?Address=*+Transport=HTTPS' "@{Port=`"5986`";Hostname=`"$($env:COMPUTERNAME)`";CertificateThumbprint=`"$($cert.Thumbprint)`"}"
}

function Enable-WinRMConfiguration {
    # Enable WinRM with defaults
    Enable-PSRemoting -Force -SkipNetworkProfileCheck

    # Override defaults to allow unlimited shells/processes/memory
    winrm set winrm/config '@{MaxTimeoutms="7200000"}'
    winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="0"}'
    winrm set winrm/config/winrs '@{MaxProcessesPerShell="0"}'
    winrm set winrm/config/winrs '@{MaxShellsPerUser="0"}'
}

Enable-WinRM

# Reset auto logon count
# https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-shell-setup-autologon-logoncount#logoncount-known-issue
#Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name AutoLogonCount -Value 0