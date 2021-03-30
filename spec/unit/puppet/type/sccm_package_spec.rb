# frozen_string_literal: true

require 'spec_helper'
require 'puppet/type/sccm_package'

RSpec.describe 'the sccm_package type' do
  it 'loads' do
    expect(Puppet::Type.type(:sccm_package)).not_to be_nil
  end
end
