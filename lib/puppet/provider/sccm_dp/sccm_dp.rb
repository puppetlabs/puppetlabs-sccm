# frozen_string_literal: true

require 'puppet/resource_api/simple_provider'

# Implementation for the sccm_dp type using the Resource API.
class Puppet::Provider::SccmDp::SccmDp < Puppet::ResourceApi::SimpleProvider
  def initialize
    super
    @confdir = "#{Puppet['codedir']}/../sccm"
    Dir.mkdir @confdir unless File.directory?(@confdir)
  end

  def get(context)
    context.debug('Collecting SCCM Distribution Point configuration resources')
    dp_files = Dir["#{@confdir}/*.dp.yaml"]
    dps = dp_files.map { |dp| YAML.load_file(dp) }
    dps.map do |dp|
      dp[:password] = dp[:password].unwrap if dp[:password].is_a?(Puppet::Pops::Types::PSensitiveType::Sensitive)
      dp
    end
  end

  def create(context, name, should)
    context.notice("Creating SCCM Distribution Point configuration resource '#{name}'")
    should[:password] = should[:password].unwrap if should[:password].is_a?(Puppet::Pops::Types::PSensitiveType::Sensitive)
    File.write("#{@confdir}/#{name}.dp.yaml", should.to_yaml)
  end

  def update(context, name, should)
    context.notice("Updating SCCM Distribution Point configuration resource '#{name}'")
    should[:password] = should[:password].unwrap if should[:password].is_a?(Puppet::Pops::Types::PSensitiveType::Sensitive)
    dp = YAML.load_file("#{@confdir}/#{name}.dp.yaml")
    new_dp = dp.merge(should)
    File.write("#{@confdir}/#{name}.dp.yaml", new_dp.to_yaml)
  end

  def delete(context, name)
    context.notice("Deleting SCCM Distribution Point configuration resource '#{name}'")
    File.delete("#{@confdir}/#{name}.dp.yaml")
  end
end
