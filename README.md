# puppetlabs-sccm

## Table of Contents

1. [Description](#description)
1. [Setup - The basics of getting started with sccm](#setup)
    * [What sccm affects](#what-sccm-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with sccm](#beginning-with-sccm)
1. [Usage - Configuration options and additional functionality](#usage)
1. [Limitations - OS compatibility, etc.](#limitations)
1. [Development - Guide for contributing to the module](#development)

## Description

This module provides a Puppet type & provider to natively download packages from SCCM distribution points over HTTP.

## Setup

### What sccm affects

This module will download a package from a SCCM distribution point and store it on the local disk. Since Windows can't install software directly from a HTTP source, the files need to be downloaded locally first. This module provide a way to do that with ease.

### Setup Requirements

To start with sccm, complete the following prerequirements:
* Ensure this module is added to your control repo's Puppetfile

### Beginning with sccm

To download an SCCM package with this module, define a `sccm_package` resource like so:
```
sccm_package{ 'PRI00005':             # <-- PRI00005 is the SCCM package ID
  ensure => present,
  dp     => 'sccmdp2.company.local',  # <-- FQDN of the SCCM distribution point
  dest   => 'C:\Windows\Temp\Pkg'     # <-- Folder in which to store packages
}
```

The above code will download the PRI00005 package from http://sccmdp2.company.local/SMS_DP_SMSPKG$/PRI00005 and store it in C:\Windows\Temp\Pkg\PRI00005.

## Usage

This module's `sccm_package` resource works well with Puppet's standard `package` resource to get a Windows application installed.
For example, to retrieve Notepad++ from SCCM and install it with Puppet, we can do the following:
```
sccm_package{ 'PRI00009':
  ensure => present,
  dp     => 'sccmdp2.company.local',
  dest   => 'C:\Windows\Temp\Pkg'
}

package { 'Notepad++ (64-bit x64)':
  ensure          => 'present',
  source          => 'C:\Windows\Temp\Pkg\PRI00009\npp.7.9.4.Installer.x64.exe',
  install_options => ['/S'],
  require         => Sccm_package['PRI00009']
}
```

## Limitations

In the Limitations section, list any incompatibilities, known issues, or other
warnings.

## Development

In the Development section, tell other users the ground rules for contributing
to your project and how they should submit their work.

## Release Notes/Contributors/Etc. **Optional**

If you aren't using changelog, put your release notes here (though you should
consider using changelog). You can also add any additional sections you feel are
necessary or important to include here. Please use the `##` header.

[1]: https://puppet.com/docs/pdk/latest/pdk_generating_modules.html
[2]: https://puppet.com/docs/puppet/latest/puppet_strings.html
[3]: https://puppet.com/docs/puppet/latest/puppet_strings_style.html
