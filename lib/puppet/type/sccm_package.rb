# frozen_string_literal: true

require 'puppet/resource_api'

Puppet::ResourceApi.register_type(
  name: 'sccm_package',
  docs: <<-DOC,
@summary a Puppet type to define an SCCM Package
@example
sccm_package { 'PRI00004':
  ensure => 'present',
  dp     => 'sccmdp1.company.local',
  dest   => 'C:/Windows/Temp/Pkg'
}
This type provides Puppet with the capabilities to manage SCCM package contents

**Autorequires**:
This type will autorequire the sccm class to ensure the ruby-ntlm gem is installed.
This type will autorequire the sccm_dp resource identified by the 'dp' attribute.
DOC
  features: ['raw_catalog_access'],
  attributes: {
    ensure: {
      type: 'Enum[present, absent]',
      desc: 'Whether this package should be present or absent on the target system.',
      default: 'present',
    },
    name: {
      type: 'String',
      desc: 'The SCCM Package ID that you want to manage.',
      behaviour: :namevar,
    },
    dp: {
      type: 'String',
      desc: 'Name of the sccm_dp resource that defines the SCCM Distribution Point to use.',
    },
    dest: {
      type: 'String',
      desc: 'Location on the local system to download the package to.',
    },
    sync_content: {
      type: 'Boolean',
      desc: 'Whether or not the local contents match the source.',
      default: true,
    },
  },
  autorequire: {
    sccm_dp: '$dp', # evaluates to the value of the `dp` attribute
  },
)
