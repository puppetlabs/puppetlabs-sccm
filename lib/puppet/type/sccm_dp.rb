# frozen_string_literal: true

require 'puppet/resource_api'

Puppet::ResourceApi.register_type(
  name: 'sccm_dp',
  docs: <<-DOC,
@summary a Puppet type to define an SCCM Distribution Point
@example
sccm_dp { 'sccmdp1.company.local':
  auth     => 'windows',
  username => 'sccm_user',
  domain   => 'COMPANY',
  password => 's3cr3t',
  ssl      => false
}
This type provides Puppet with the necessary information about distribution points
DOC
  features: [],
  attributes: {
    ensure: {
      type: 'Enum[present, absent]',
      desc: 'Whether this SCCM Distribution Point config should be defined on the target system.',
      default: 'present',
    },
    name: {
      type: 'String',
      desc: 'FQDN of the SCCM Distribution Point to download from.',
      behaviour: :namevar,
    },
    auth: {
      type: 'Enum[none, windows]',
      desc: 'Type of authentication the SCCM Distribution Point requires.',
      default: 'none',
    },
    username: {
      type: 'String',
      desc: 'Username for Windows Authentication (HTTP) to the SCCM Distribution Point.',
      default: '',
    },
    domain: {
      type: 'String',
      desc: 'Domain name (NetBIOS) for Windows Authentication (HTTP) to the SCCM Distribution Point.',
      default: '',
    },
    password: {
      type: 'Variant[String,Sensitive[String]]',
      sensitive: true,
      desc: 'Password for Windows Authentication (HTTP) to the SCCM Distribution Point.',
      default: '',
    },
    ssl: {
      type: 'Boolean',
      desc: 'Whether the SCCM Distribution Point requires HTTP or HTTPS. Currently only HTTP is supported.',
      default: false,
    },
  },
)
