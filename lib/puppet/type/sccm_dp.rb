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
      type: 'Enum[none, windows, certauth]',
      desc: 'Type of authentication the SCCM Distribution Point requires.',
      default: 'none',
    },
    username: {
      type: 'Optional[String]',
      desc: 'Username for Windows Authentication (HTTP) to the SCCM Distribution Point.',
      mandatory_for_get: false,
      mandatory_for_set: false,
    },
    domain: {
      type: 'Optional[String]',
      desc: 'Domain name (NetBIOS) for Windows Authentication (HTTP) to the SCCM Distribution Point.',
      mandatory_for_get: false,
      mandatory_for_set: false,
    },
    password: {
      type: 'Optional[Variant[String,Sensitive[String]]]', # Sensitive does not currently work
      sensitive: true,
      desc: 'Password for Windows Authentication (HTTP) to the SCCM Distribution Point.',
      mandatory_for_get: false,
      mandatory_for_set: false,
    },
    ssl: {
      type: 'Boolean',
      desc: 'Whether the SCCM Distribution Point requires HTTP or HTTPS.',
      default: false,
    },
    issuer: {
      type: 'Optional[String]',
      desc: 'Name of the certificate issuer to filter on for selecting a suitable client certificate for HTTPS authentication.',
      mandatory_for_get: false,
      mandatory_for_set: false,
    },
  },
)
