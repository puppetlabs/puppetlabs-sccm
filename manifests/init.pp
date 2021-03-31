# Class: sccm
#
#
class sccm {
  # resources
  package { 'ruby-ntlm':
    ensure   => 'present',
    provider => 'puppet_gem'
  }
}
