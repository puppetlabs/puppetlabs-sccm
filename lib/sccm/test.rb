require 'yaml'
require 'net/http'
require 'uri'
require_relative 'ruby-ntlm/ntlm/http'
require_relative 'iniparse/iniparse'

def get_content_location(pkg_uri)
    auth_type = 'windows'
    auth_user = 'administrator'
    auth_domain = 'dreamworx'
    auth_password = 'P1gg3lm33'
    response = make_request(pkg_uri, :get, auth_type, auth_user, auth_domain, auth_password)
    pkg_ini = response.body
    pkg = IniParse.parse(pkg_ini)
    pkg['Packages'].each do |line|
      return line.key
    end
end

def make_request(endpoint, type, auth_type = 'none', auth_user = nil, auth_domain = nil, auth_password = nil)
    uri = URI.parse(endpoint)
    if auth_type == 'pki'
      uri.scheme = 'https'
      uri = URI.parse(uri.to_s)
    end

    connection = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == 'https'
      connection.use_ssl = true
      connection.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    connection.read_timeout = 60

    max_attempts = 3
    attempts = 0

    while attempts < max_attempts
      attempts += 1
      begin
        puts "sccm_package: performing #{type} request to #{endpoint}"
        case type
        when :get
          request = Net::HTTP::Get.new(uri.request_uri)
        when :head
          request = Net::HTTP::Head.new(uri.request_uri)
        else
          puts "sccm_package#make_request called with invalid request type #{type}"
        end
        request.ntlm_auth(auth_user, auth_domain, auth_password) if auth_type == 'windows'
        request.method
        response = connection.request(request)
      rescue SocketError => e
        puts "Could not connect to the SCCM endpoint at #{uri.host}: #{e.inspect}", e.backtrace
      end

      case response
      when Net::HTTPInternalServerError
        if attempts < max_attempts # rubocop:disable Style/GuardClause
          puts "Received #{response} error from #{uri.host}, attempting to retry. (Attempt #{attempts} of #{max_attempts})"
          Kernel.sleep(3)
        else
          puts "Received #{attempts} server error responses from the SCCM endpoint at #{uri.host}: #{response.code} #{response.body}"
        end
      else # Covers Net::HTTPSuccess, Net::HTTPRedirection
        return response
      end
    end
end

puts get_content_location('http://sccm.dreamworx.nl/SMS_DP_SMSPKG$/PkgLib/DWX0000A.INI')
