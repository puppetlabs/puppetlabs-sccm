# frozen_string_literal: true

require 'puppet/resource_api/simple_provider'
require 'yaml'
require 'net/http'
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
    pkg_files = Dir["#{@confdir}/*.yaml"]
    pkgs = pkg_files.map { |pkg| YAML.load_file(pkg) }
    pkgs.map do |pkg|
      exists = File.directory?(pkg[:dest])
      pkg[:ensure] = exists ? 'present' : 'absent'
      pkg_uri = "http://#{pkg[:dp]}/SMS_DP_SMSPKG$/#{pkg[:name]}"
      list_of_files = recursive_download_list(pkg_uri)
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
      pkg
    end
  end

  def create(context, name, should)
    context.notice("SCCM package '#{name}' with #{should.inspect}")
    File.write("#{@confdir}/#{name}.yaml", should.to_yaml)
    sync_contents(context, name, should)
  end

  def update(context, name, should)
    context.notice("SCCM package '#{name}' with #{should.inspect}")
    pkg = YAML.load_file("#{@confdir}/#{name}.yaml")
    new_pkg = pkg.merge(should)
    remove_dir("#{pkg[:dest]}/#{name}") unless pkg[:dest] == new_pkg[:dest]
    File.write("#{@confdir}/#{name}.yaml", new_pkg.to_yaml)
    sync_contents(context, name, should)
  end

  def delete(context, name)
    context.notice("SCCM package '#{name}'")
    pkg = YAML.load_file("#{@confdir}/#{name}.yaml")
    remove_dir("#{pkg[:dest]}/#{name}")
    File.delete("#{@confdir}/#{name}.yaml")
  end

  def sync_contents(context, name, should)
    pkg_uri = "http://#{should[:dp]}/SMS_DP_SMSPKG$/#{name}"
    list_of_files = recursive_download_list(pkg_uri)
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
      http_download(context, key, "#{should[:dest]}/#{name}/#{file_path}") if download
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

  def recursive_download_list(uri)
    result = {}
    head = make_request(uri, :head)
    if head['Content-Length'].to_i.positive?
      result[uri] = head['Content-Length']
    elsif head['Content-Length'].to_i.zero?
      response = make_request(uri, :get)
      links = response.body.scan(%r{<a href="(.+?)">})
      links.each do |link|
        lookup = recursive_download_list(link[0])
        lookup.each do |key, value|
          result[key] = value
        end
      end
    end
    result
  end

  def make_request(endpoint, type)
    uri = URI.parse(endpoint)

    connection = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == 'https'
      connection.use_ssl = true
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

  def http_download(context, resource, filename)
    uri = URI(resource)
    context.notice("Downloading SCCM package file: #{uri}")
    http_object = Net::HTTP.new(uri.host, uri.port)
    http_object.use_ssl = true if uri.scheme == 'https'
    begin
      http_object.start do |http|
        request = Net::HTTP::Get.new uri
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
