# frozen_string_literal: true

require 'puppet/resource_api/simple_provider'
require 'yaml'
require 'net/http'
require 'ntlm/http'
require 'uri'

# Implementation for the sccm_package type using the Resource API.
class Puppet::Provider::SccmPackage::SccmPackage < Puppet::ResourceApi::SimpleProvider
  def initialize
    super
    @confdir = "#{Puppet['codedir']}/../sccm"
    Dir.mkdir @confdir unless File.directory?(@confdir)
  end

  def get(context)
    context.debug('Returning info for SCCM packages')
    dp_files = Dir["#{@confdir}/*.dp.yaml"]
    dps = dp_files.map { |dp| YAML.load_file(dp) }
    pkg_files = Dir["#{@confdir}/*.pkg.yaml"]
    pkgs = pkg_files.map { |pkg| YAML.load_file(pkg) }
    pkgs.map do |pkg|
      exists = File.directory?(pkg[:dest])
      pkg[:ensure] = exists ? 'present' : 'absent'
      dps.each do |dp|
        next unless dp[:name] == pkg[:dp]
        pkg_proto = dp[:ssl] ? 'https' : 'http'
        pkg_uri = "#{pkg_proto}://#{dp[:name]}/SMS_DP_SMSPKG$/#{pkg[:name]}"
        case dp[:auth]
        when 'none'
          list_of_files = recursive_download_list(pkg_uri)
        when 'windows'
          list_of_files = recursive_download_list(pkg_uri, 'windows', dp[:username], dp[:domain], dp[:password])          
        else
          raise Puppet::ResourceError, "Unsupported authentication type for SCCM Distribution Point: '#{dp[:auth]}'. Valid values are 'none', 'windows' and 'pki'."
        end
        in_sync = true
        list_of_files.each do |key, value|
          uri_match = pkg_uri.gsub(%r{\.}, '\.').gsub(%r{\$}, '\$').gsub(%r{\/}, '\/')
          file_path = key.gsub(%r{#{uri_match}\.\d+?\/}, '')
          if File.exist?("#{pkg[:dest]}/#{pkg[:name]}/#{file_path}")
            in_sync = false unless File.size("#{pkg[:dest]}/#{pkg[:name]}/#{file_path}").to_i == value.to_i
          else
            in_sync = false
          end
        end
        pkg[:sync_content] = in_sync
      end
      pkg
    end
  end

  def create(context, name, should)
    context.notice("SCCM package '#{name}' with #{should.inspect}")
    File.write("#{@confdir}/#{name}.pkg.yaml", should.to_yaml)
    sync_contents(context, name, should)
  end

  def update(context, name, should)
    context.notice("SCCM package '#{name}' with #{should.inspect}")
    pkg = YAML.load_file("#{@confdir}/#{name}.pkg.yaml")
    new_pkg = pkg.merge(should)
    remove_dir("#{pkg[:dest]}/#{name}") unless pkg[:dest] == new_pkg[:dest]
    File.write("#{@confdir}/#{name}.pkg.yaml", new_pkg.to_yaml)
    sync_contents(context, name, should)
  end

  def delete(context, name)
    context.notice("SCCM package '#{name}'")
    pkg = YAML.load_file("#{@confdir}/#{name}.pkg.yaml")
    remove_dir("#{pkg[:dest]}/#{name}")
    File.delete("#{@confdir}/#{name}.pkg.yaml")
  end

  def sync_contents(context, name, should)
    dp_files = Dir["#{@confdir}/*.dp.yaml"]
    dps = dp_files.map { |dp| YAML.load_file(dp) }
    dps.each do |dp|
      next unless dp[:name] == should[:dp]
      pkg_proto = dp[:ssl] ? 'https' : 'http'
      pkg_uri = "#{pkg_proto}://#{dp[:name]}/SMS_DP_SMSPKG$/#{name}"
      case dp[:auth]
      when 'none'
        list_of_files = recursive_download_list(pkg_uri)
      when 'windows'
        list_of_files = recursive_download_list(pkg_uri, 'windows', dp[:username], dp[:domain], dp[:password])          
      else
        raise Puppet::ResourceError, "Unsupported authentication type for SCCM Distribution Point: '#{dp[:auth]}'. Valid values are 'none', 'windows' and 'pki'."
      end
      list_of_files.each do |key, value|
        uri_match = pkg_uri.gsub(%r{\.}, '\.').gsub(%r{\$}, '\$').gsub(%r{\/}, '\/')
        file_path = key.gsub(%r{#{uri_match}\.\d+?\/}, '')
        Puppet::FileSystem.dir_mkpath("#{should[:dest]}/#{name}/#{file_path}")
        download = false
        if ! File.exist?("#{should[:dest]}/#{name}/#{file_path}")
          download = true
        else
          if ! File.size("#{should[:dest]}/#{name}/#{file_path}") == value
            download = true
          end
        end
        case dp[:auth]
        when 'none'
          http_download(context, key, "#{should[:dest]}/#{name}/#{file_path}") if download
        when 'windows'
          http_download(context, key, "#{should[:dest]}/#{name}/#{file_path}", 'windows', dp[:username], dp[:domain], dp[:password]) if download
        else
          raise Puppet::ResourceError, "Unsupported authentication type for SCCM Distribution Point: '#{dp[:auth]}'. Valid values are 'none', 'windows' and 'pki'."
        end
      end
    end
  end

  def remove_dir(path)
    if File.directory?(path)
      Dir.foreach(path) do |file|
        if ((file.to_s != ".") and (file.to_s != ".."))
          remove_dir("#{path}/#{file}")
        end
      end
      Dir.delete(path)
    else
      File.delete(path)
    end
  end

  def recursive_download_list(uri, auth_type = 'none', auth_user = nil, auth_domain = nil, auth_password = nil)
    result = {}
    head = make_request(uri, :head, auth_type, auth_user, auth_domain, auth_password)
    raise Puppet::ResourceError, "Failed to connect to SCCM Distribution Point! Got error #{head.code}, #{head.message}" unless head.code.to_i == 200
    if head['Content-Length'].to_i.positive? && head['Content-Type'] == 'application/octet-stream'
      result[uri] = head['Content-Length']
    elsif head['Content-Length'].to_i.zero?
      response = make_request(uri, :get, auth_type, auth_user, auth_domain, auth_password)
      links = response.body.scan(%r{<a href="(.+?)">})
      links.each do |link|
        lookup = recursive_download_list(link[0], auth_type, auth_user, auth_domain, auth_password)
        lookup.each do |key, value|
          result[key] = value
        end
      end
    end
    result
  end

  def make_request(endpoint, type, auth_type = 'none', auth_user = nil, auth_domain = nil, auth_password = nil)
    uri = URI.parse(endpoint)

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
        Puppet.debug("sccm_package: performing #{type} request to #{endpoint}")
        case type
        when :get
          request = Net::HTTP::Get.new(uri.request_uri)
        when :head
          request = Net::HTTP::Head.new(uri.request_uri)
        else
          raise Puppet::Error, "sccm_package#make_request called with invalid request type #{type}"
        end
        if auth_type == 'windows'
          request.ntlm_auth(auth_user, auth_domain, auth_password)
        end
        request.method
        response = connection.request(request)
      rescue SocketError => e
        raise Puppet::Error, "Could not connect to the SCCM endpoint at #{uri.host}: #{e.inspect}", e.backtrace
      end

      case response
      when Net::HTTPInternalServerError
        if attempts < max_attempts # rubocop:disable Style/GuardClause
          Puppet.debug("Received #{response} error from #{uri.host}, attempting to retry. (Attempt #{attempts} of #{max_attempts})")
          Kernel.sleep(3)
        else
          raise Puppet::Error, "Received #{attempts} server error responses from the SCCM endpoint at #{uri.host}: #{response.code} #{response.body}"
        end
      else # Covers Net::HTTPSuccess, Net::HTTPRedirection
        return response
      end
    end
  end

  def http_download(context, resource, filename, auth_type = 'none', auth_user = nil, auth_domain = nil, auth_password = nil)
    uri = URI(resource)
    context.notice("Downloading SCCM package file: #{uri}")
    http_object = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == 'https'
      http_object.use_ssl = true
      http_object.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    begin
      http_object.start do |http|
        request = Net::HTTP::Get.new uri
        if auth_type == 'windows'
          request.ntlm_auth(auth_user, auth_domain, auth_password)
        end
        http.read_timeout = 60
        http.request request do |response|
          open filename, 'wb' do |io|
            response.read_body do |chunk|
              io.write chunk
            end
          end
        end
      end
    rescue Exception => e
      raise Puppet::ResourceError, "Error downloading #{resource}: '#{e}'"
    end
    context.debug("Stored download as #{filename}.")
  end
end
