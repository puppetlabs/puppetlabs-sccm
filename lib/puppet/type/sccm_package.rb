# frozen_string_literal: true

require 'puppet/resource_api'

Puppet::ResourceApi.register_type(
  name: 'sccm_package',
  docs: <<-DOC,
@summary a sccm_package type
@example
sccm_package { 'PRI00004':
  ensure => 'present',
  dp     => 'sccm_dp.company.local',
  dest   => 'C:/Windows/Temp/Pkg'
}
This type provides Puppet with the capabilities to manage SCCM package contents
DOC
  features: [],
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
      desc: 'FQDN of the SCCM Distribution Point to download from.',
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
)
