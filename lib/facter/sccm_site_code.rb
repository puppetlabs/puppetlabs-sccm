Facter.add('sccm_site_code') do
  confine kernel: 'windows'
  setcode do
    begin
      value = nil
      Win32::Registry::HKEY_LOCAL_MACHINE.open('SOFTWARE\\Microsoft\\SMS\\Mobile Client') do |regkey|
        value = regkey['AssignedSiteCode']
      end
      value
    rescue
      nil
    end
  end
end
