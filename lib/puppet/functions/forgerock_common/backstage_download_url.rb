# frozen_string_literal: true

# @summary
#   This function generates a download URL for a given ForgeRock product based on the provided parameters.
#
Puppet::Functions.create_function(:'forgerock_common::backstage_download_url') do
  # @param product_family_id [String] The product family ID (e.g., 'am').
  # @param product_id [String] The product ID (e.g., 'openam-web-policy-agents').
  # @param version [String] The version of the product (e.g., '2025.11', '7.5.0').
  # @param distribution [String] The distribution type (e.g., 'zip', 'war').
  # @param release_type [String, nil] The release type (e.g., 'full', 'patch'). Required for some products.
  # @param platform [String, nil] The platform (e.g., 'apache'). Required for some products.
  # @param platform_version [String, nil] The platform version (e.g., '2.4'). Required for some products.
  # @param os [String, nil] The operating system (e.g., 'linux'). Required for some products.
  # @param architecture [String, nil] The architecture (e.g., '64bit'). Required for some products.
  # @param include_system_ca_store [Boolean, nil] Whether to include the system CA store when making HTTP requests. Defaults to false.
  # @return [String] The generated download URL.
  dispatch :backstage_download_url do
    param 'String', :product_family_id
    param 'String', :product_id
    param 'String', :version
    param 'String', :distribution
    optional_param 'String', :release_type
    optional_param 'String', :platform
    optional_param 'String', :platform_version
    optional_param 'String', :os
    optional_param 'String', :architecture
    optional_param 'Boolean', :include_system_ca_store
    return_type 'String'
  end

  def backstage_download_url(product_family_id, product_id, version, distribution, release_type = nil, platform = nil, platform_version = nil, os = nil, architecture = nil, include_system_ca_store = false)
    http_client = Puppet.runtime[:http]
    product_tree = 'https://backstage.pingidentity.com/product-tree-ws/api/v1/producttree/master'
    download_base_url = 'https://backstage.pingidentity.com/cloud-storage-ws/api/v1/cloudstorage/getfile'

    if product_id == 'openam-web-policy-agents'
      raise Puppet::Error, "Platform, platform_version, os, and architecture must be specified for product_family_id=#{product_family_id}, product_id=#{product_id}" if [platform, platform_version, os, architecture].any? { |v| v.nil? || v.empty? }
    elsif release_type.nil? || release_type.empty?
      raise Puppet::Error, "Release_type must be specified for product_family_id=#{product_family_id}, product_id=#{product_id}"
    end

    begin
      uri = URI.parse(Puppet::Util.uri_encode(product_tree))
    rescue StandardError => e
      raise Puppet::Error, "Could not understand source #{product_tree}: #{e}", e
    end

    response = http_client.get(uri, options: { include_system_store: include_system_ca_store })
    raise Puppet::Error, "Could not retrieve artifact information from #{uri}: #{response.code} #{response.reason}" unless response.success?

    version_parts = version.split('.')
    dist_version = if version_parts[1] == '0'
                     version_parts[0]
                   else
                     version_parts[0..1].join('.')
                   end
    data = JSON.parse(response.body)['data']

    version_json = version(
      versions_from_minor_version(
        minor_version(
          minor_versions_from_product(
            product(
              products_from_family(
                family(
                  families_from_data(data), product_family_id
                ),
              ), product_id
            ),
          ), dist_version
        ),
      ), version
    )

    dist_json = if product_family_id == 'am' && product_id == 'openam-web-policy-agents'
                  distribution(
                    distributions_from_architecture(
                      architecture(architectures_from_os(
                                     os(
                                       oses_from_platform_version(
                                         platform_version(
                                           platform_versions_from_platform(
                                             platform(
                                               platforms_from_version(version_json), platform
                                             ),
                                           ), platform_version
                                         ),
                                       ), os
                                     ),
                                   ), architecture),
                    ), distribution
                  )
                else
                  distribution(
                    distributions_from_release_type(
                      release_type(
                        release_types_from_version(version_json), release_type
                      ),
                    ), distribution
                  )
                end

    artifact_id = dist_json['artifactId'] if dist_json
    raise Puppet::Error, "Could not find artifact for family_id=#{product_family_id}, product_id=#{product_id}, version=#{version}, platform=#{platform}, platform_version=#{platform_version}, os=#{os}, architecture=#{architecture}, distribution=#{distribution}" if artifact_id.nil?

    "#{download_base_url}/#{artifact_id}"
  end

  # helpers #

  def families_from_data(data)
    data['children'] || raise(Puppet::Error, "Could not find family ids in #{data}")
  end

  def family(families, product_family_id)
    families.find { |f| f['familyId'] == product_family_id } || raise(Puppet::Error, "Could not find family for #{product_family_id}")
  end

  def products_from_family(family)
    family['children'] || raise(Puppet::Error, "Could not find products for #{family}")
  end

  def product(products, product_id)
    products.find { |p| p['productId'] == product_id } || raise(Puppet::Error, "Could not find product for #{product_id}")
  end

  def minor_versions_from_product(product)
    product['children'] || raise(Puppet::Error, "Could not find minor versions for #{product}")
  end

  def minor_version(minor_versions, version)
    minor_versions.find { |v| v['minorVersion'] == version } || raise(Puppet::Error, "Could not find minor version for #{version}")
  end

  def versions_from_minor_version(minor_version)
    minor_version['children'] || raise(Puppet::Error, "Could not find versions for #{minor_version}")
  end

  def version(versions, version)
    versions.find { |v| v['version'] == version } || raise(Puppet::Error, "Could not find version for #{version}")
  end

  def release_types_from_version(version)
    version['children'] || raise(Puppet::Error, "Could not find release types for #{version}")
  end

  def release_type(release_types, release_type)
    release_types.find { |r| r['releaseType'] == release_type } || raise(Puppet::Error, "Could not find release type for #{release_type}")
  end

  def platforms_from_version(version)
    version['children'] || raise(Puppet::Error, "Could not find platforms for #{version}")
  end

  def platform(platforms, platform)
    platforms.find { |p| p['platform'] == platform } || raise(Puppet::Error, "Could not find platform for #{platform}")
  end

  def platform_versions_from_platform(platform)
    platform['children'] || raise(Puppet::Error, "Could not find platform versions for #{platform}")
  end

  def platform_version(platform_versions, platform_version)
    platform_versions.find { |pv| pv['platformVersion'] == platform_version } || raise(Puppet::Error, "Could not find platform version for #{platform_version}")
  end

  def oses_from_platform_version(platform_version)
    platform_version['children'] || raise(Puppet::Error, "Could not find OSes for #{platform_version}")
  end

  def os(oses, os)
    oses.find { |o| o['os'] == os } || raise(Puppet::Error, "Could not find OS for #{os}")
  end

  def architectures_from_os(os)
    os['children'] || raise(Puppet::Error, "Could not find architectures for #{os}")
  end

  def architecture(architectures, architecture)
    architectures.find { |a| a['architecture'] == architecture } || raise(Puppet::Error, "Could not find architecture for #{architecture}")
  end

  def distributions_from_architecture(architecture)
    architecture['children'] || raise(Puppet::Error, "Could not find distributions for #{architecture}")
  end

  def distributions_from_release_type(release_type)
    release_type['children'] || raise(Puppet::Error, "Could not find distributions for #{release_type}")
  end

  def distribution(distributions, distribution)
    distributions.find { |d| d['distribution'] == distribution } || raise(Puppet::Error, "Could not find distribution for #{distribution}")
  end
end
