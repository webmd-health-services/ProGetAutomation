# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure('2') do |config|
  config.vm.define 'proget' do |proget|
    # https://app.vagrantup.com/gusztavvargadr/boxes/sql-server
    proget.vm.box = 'gusztavvargadr/sql-server'

    proget.vm.network 'forwarded_port', guest: 8624, host: 8624

    proget.vm.provider 'virtualbox' do |vb|
      vb.gui = true
      vb.memory = '4096'
    end

    proget.vm.provider 'hyperv' do |hv|
      hv.memory = '4096'
    end

    proget.vm.provision 'shell', inline: <<-'SHELL'
      $ErrorActionPreference = 'Stop'

      # InedoHub installs ProGet to run as the Network Service built-in.
      sqlcmd.exe -Q 'CREATE LOGIN [NT AUTHORITY\NETWORK SERVICE] FROM WINDOWS;'

      New-NetFirewallRule -DisplayName 'Allow ProGet Web Server' -Direction Inbound -Protocol TCP -LocalPort 8624 | Out-Null
      iwr https://raw.githubusercontent.com/webmd-health-services/Prism/main/Scripts/init.ps1 -UseBasicParsing | iex | Format-Table
      C:\Vagrant\init.ps1 -SqlServerName 'localhost'
    SHELL
  end
end