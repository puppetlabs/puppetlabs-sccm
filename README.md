# puppetlabs-sccm

## Table of Contents

1. [Description](#description)
1. [Setup - The basics of getting started with sccm](#setup)
    * [What sccm affects](#what-sccm-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with sccm](#beginning-with-sccm)
1. [Usage - Configuration options and additional functionality](#usage)

## Description

This module provides Puppet types & providers to natively download packages from SCCM distribution points over HTTP/HTTPS. This module supports HTTP with either anonymous or Windows authentication, and HTTPS with client certificate authentication.

## Setup

### What sccm affects

This module will download a package from a SCCM distribution point and store it on the local disk. Since Windows can't install software directly from a HTTP(S) source, the files need to be downloaded locally first. This module provide a way to do that with ease.

### Setup Requirements

To start with sccm, complete the following prerequirements:

* Ensure this module is added to your control repo's Puppetfile
* This module uses the Puppet Resource API. This is built-in to Puppet 6.x and higher.

### Beginning with sccm

To download an SCCM package with this module, we need to define two things:

* An `sccm_dp` resource to identify an SCCM Distribution Point
* An `sccm_package` resource to identify the package we want to download & manage

Example for a SCCM Distribution Point with anonymous HTTP access:

```puppet
sccm_dp { 'sccmdp2.company.local':    # <-- FQDN of the SCCM distribution point
  auth     => 'none'                  # <-- 'none' for anonymous authentication
}

sccm_package{ 'PRI00005':             # <-- PRI00005 is the SCCM package ID
  ensure => present,
  dp     => 'sccmdp2.company.local',  # <-- Must match name of sccm_dp resource
  dest   => 'C:\Windows\Temp\Pkg'     # <-- Folder in which to store packages
}
```

The above code will download the PRI00005 package from `http://sccmdp2.company.local/SMS_DP_SMSPKG$/PRI00005` and store it in C:\Windows\Temp\Pkg\PRI00005.

Example for the same situation but now with authenticated HTTP access:

```puppet
sccm_dp { 'sccmdp2.company.local':     # <-- FQDN of the SCCM distribution point
  auth     => 'windows',               # <-- 'windows' for Windows authentication
  username => 'svcSCCM',               # <-- Username for authentication
  domain   => 'companyAD',             # <-- Domain name (NetBIOS) for authentication
  password => 's3cr3tp@ss',            # <-- Password for authentication
}

sccm_package{ 'PRI00005':              # <-- PRI00005 is the SCCM package ID
  ensure => present,
  dp     => 'sccmdp2.company.local',   # <-- Must match name of sccm_dp resource
  dest   => 'C:\Windows\Temp\Pkg'      # <-- Folder in which to store packages
}
```

Example for a Distribution Point with HTTPS access and TLS client authentication:

```puppet
sccm_dp { 'sccmdp3.company.local':                       # <-- FQDN of the SCCM distribution point
  auth         => 'pki',                                 # <-- 'pki' for TLS client authentication
  ssl          => true                                   # <-- Use HTTPS instead of HTTP
  pfx          => 'C:\Windows\Temp\sccm_dp_access.pfx'   # <-- Local PFX file that contains the TLS client certificate
  pfx_password => 'puppetlabs'                           # <-- Password to import the TLS client cert in the PFX file
}
```

## Usage

This module's `sccm_package` resource works well with Puppet's standard `package` resource to get a Windows application installed.
For example, to retrieve Notepad++ from SCCM and install it with Puppet, we can do the following:

```puppet
sccm_dp { 'sccmdp2.company.local':
  auth     => 'none'
}

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

### Recommended Usage

The most flexible way to use this module in production is to make the Puppet code fully dynamic, and move the definition & selection of packages to Hiera. Some aspects like which Sites and Distribution Points exist, as well as info about each package, is best maintained in Hiera and then leveraged in your Puppet code.

This module provides a `sccm_site_code` fact, that will report the SCCM Site the machine is assigned to if the SCCM Client is installed. You can take advantage of this in Hiera.

For example, let's create the following structure (a YAML file per SCCM site) in Hiera:

```bash
data/sccm_sites/S01.yaml
data/sccm_sites/S02.yaml
```

and then extend `hiera.yaml` to include the SCCM site YAML files in the hierarchy:

`hiera.yaml`
```yaml
---
version: 5

defaults:
  datadir: 'data'

hierarchy:
  - name: 'Yaml backend'
    data_hash: yaml_data
    paths:
      - "nodes/%{trusted.certname}.yaml"
      - "sccm_sites/%{sccm_site_code}.yaml"
      - 'common.yaml'
```

Next, we can populate the relevant information for a site:

`data/sccm_sites/S01.yaml`
```yaml
sccm::networks:
  '10.10.20.0': sccmdp1.company.local
  '10.10.30.0': sccmdp2.company.local

sccm::distribution_points:
  sccmdp1.company.local:
    auth: pki
    ssl: true
    pfx: C:\Windows\Temp\sccm_dp_access.pfx
    pfx_password: puppetlabs
  sccmdp2.company.local:
    auth: windows
    username: svcSCCM
    domain: companyAD
    password: s3cr3tp@ss

sccm::packages:
  winrar:
    id: S0100006
    install:
      file: winrar-x64-600.exe
      args:
        - /S
  notepad++:
    id: S0100007
    name: Notepad++ (64-bit x64)
    install:
      file: npp.7.9.4.Installer.x64.exe
      args:
        - /S
```

This structures all the relevant information for us, and allows us to reference packages by a friendly name, instead of the SCCM Package ID. That way, if the Package ID changes for whatever reason, you can update this in a single location.

Next, we need to build a Puppet profile with the logic to parse the information from Hiera:

`site-modules/profile/manifests/sccm_packages.pp`
```puppet
# Class: profile::sccm_packages
# This profile downloads & installs packages from SCCM
#
class profile::sccm_packages(
  $apps,
  $dest = 'C:\Windows\Temp\Pkg'
) {
  $networks   = lookup('sccm::networks')
  $dp_configs = lookup('sccm::distribution_points')
  $dp         = $networks[$facts['network']]

  file { 'C:/Windows/Temp/sccm_dp_access.pfx':
    ensure => present,
    source => 'puppet:///modules/profile/sccm_dp_access.pfx'
  }

  sccm_dp { $dp:
    *       => $dp_configs[$dp],
    require => File['C:/Windows/Temp/sccm_dp_access.pfx']
  }

  $pkgs = lookup('sccm::packages')
  $apps.each |$app| {
    sccm_package { $pkgs[$app]['id']:
      ensure => 'present',
      dp     => $dp,
      dest   => $dest
    }

    package { $pkgs[$app]['name']:
      ensure          => 'present',
      source          => "${dest}\\${pkgs[$app]['id']}\\${pkgs[$app]['install']['file']}",
      install_options => $pkgs[$app]['install']['args'],
      require         => Sccm_package[$pkgs[$app]['id']]
    }
  }
}
```

In the above profile, we include a `file {'C:/Windows/Temp/sccm_dp_access.pfx':}` resource to place the PFX file for TLS client authentication on the local system, and make sure this happens before any distribution points are accessed.

The profile above will, in the context of each node's assigned SCCM Site:

* Lookup the mapping of subnets to distribution points in the `sccm::networks` hash, and select the correct distribution point based on a matching entry to the `network` fact of the node
* Lookup the configurations of all distribution points in the `sccm::distribution_points` hash, and create a `sccm_dp` resource with the configuration for that specific distribution point
* Lookup all available SCCM packages in the `sccm::packages` hash
* Create `sccm_package` resources for any apps passed to the profile in the `$apps` parameter (we will lookup this parameter in Hiera below)
* Create `package` resources for any apps passed to the profile in the `$apps` parameter, to actually install the application

Finally, we can specify the value for `$apps` on individual nodes, or groups of nodes, using Hiera again:

`data/nodes/server1.company.com.yaml`
```yaml
profile::sccm_packages::apps:
  - winrar
  - notepad++
```

This will cause WinRAR and Notepad++ to get installed by downloading their respective packages from SCCM, and installing the software as described in the `sccm::packages` hash for the site.

## Limitations

* This module does not currently support passing the value to the `password` or `pfx_password` parameters of a `sccm_dp` resource as a `Sensitive` datatype. A change in the Puppet Resource API is needed to enable this scenario properly. Once the Resource API is updated, a new version of this module will be released that supports passing a Sensitive value.
* This module was tested against Microsoft Endpoint Configuration Manager, build 2002.
