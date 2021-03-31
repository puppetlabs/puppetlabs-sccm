# frozen_string_literal: true

require 'spec_helper'
require 'puppet/type/sccm_dp'

RSpec.describe 'the sccm_dp type' do
  it 'loads' do
    expect(Puppet::Type.type(:sccm_dp)).not_to be_nil
  end
end
