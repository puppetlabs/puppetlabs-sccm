# frozen_string_literal: true

require 'puppet/resource_api'

Puppet::ResourceApi.register_type(
  name: 'sccm_dp',
  docs: <<-DOC,
@summary a Puppet type to define an SCCM Distribution Point
@example
sccm_dp { 'sccmdp1.company.local':
  auth => 'none',
  ssl  => false
}
This type provides Puppet with the necessary information about distribution points
DOC
  features: [],
  attributes: {
    name: {
      type: 'String',
      desc: 'FQDN of the SCCM Distribution Point to download from.',
      behaviour: :namevar,
    },
    auth: {
      type: 'Enum[none, windows, pki]',
      desc: 'Type of authentication the SCCM Distribution Point requires.',
      default: 'none',
    },
    ssl: {
      type: 'Boolean',
      desc: 'Whether the SCCM Distribution Point requires HTTP or HTTPS.',
      default: false,
    },
  },
)
