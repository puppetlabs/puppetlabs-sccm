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
    context.debug('Returning pre-canned example data')
    dp_files = Dir["#{@confdir}/*.dp.yaml"]
    dps = dp_files.map { |dp| YAML.load_file(dp) }
    dps.map do |dp|
      dp
    end
  end

  def create(context, name, should)
    context.notice("Creating '#{name}' with #{should.inspect}")
    File.write("#{@confdir}/#{name}.dp.yaml", should.to_yaml)
  end

  def update(context, name, should)
    context.notice("Updating '#{name}' with #{should.inspect}")
    dp = YAML.load_file("#{@confdir}/#{name}.dp.yaml")
    new_dp = dp.merge(should)
    File.write("#{@confdir}/#{name}.dp.yaml", new_dp.to_yaml)
  end

  def delete(context, name)
    context.notice("Deleting '#{name}'")
    File.delete("#{@confdir}/#{name}.dp.yaml")
  end
end
