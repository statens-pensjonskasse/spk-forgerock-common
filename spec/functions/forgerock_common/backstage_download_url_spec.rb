# frozen_string_literal: true

require 'spec_helper'

describe 'forgerock_common::backstage_download_url' do
  it { is_expected.not_to be_nil }

  context 'with invalid family' do
    it 'raises an error' do
      is_expected.to run.with_params(
        'invalid_family', 'openam-web-policy-agents', '2025.11', 'zip', '', 'apache', '2.4', 'linux', '64bit'
      ).and_raise_error(Puppet::Error, %r{Could not find family for})
    end
  end

  context 'with web policy agent parameters' do
    it 'raises an error if platform, platform_version, os, or architecture is missing' do
      is_expected.to run.with_params(
        'am', 'openam-web-policy-agents', '2025.11', 'zip', '', 'apache', '2.4', 'linux'
      ).and_raise_error(Puppet::Error, %r{Platform, platform_version, os, and architecture must be specified})
    end

    it 'returns the correct download URL' do
      is_expected.to run.with_params(
        'am', 'openam-web-policy-agents', '2025.11', 'zip', '', 'apache', '2.4', 'linux', '64bit'
      ).and_return('https://backstage.pingidentity.com/cloud-storage-ws/api/v1/cloudstorage/getfile/G7yqp558Qq-nljH6bukpSA')

      is_expected.to run.with_params(
        'am', 'openam-web-policy-agents', '5.10.3', 'zip', '', 'apache', '2.4', 'linux', '64bit'
      ).and_return('https://backstage.pingidentity.com/cloud-storage-ws/api/v1/cloudstorage/getfile/_kKWcJKzTUi2HMUH5ZADkA')
    end
  end

  context 'with am parameters' do
    it 'raises an error if release_type is missing' do
      is_expected.to run.with_params(
        'am', 'am', '7.5.2', 'war'
      ).and_raise_error(Puppet::Error, %r{Release_type must be specified})
    end

    it 'returns the correct download URL' do
      is_expected.to run.with_params(
        'am', 'am', '7.5.2', 'war', 'full'
      ).and_return('https://backstage.pingidentity.com/cloud-storage-ws/api/v1/cloudstorage/getfile/n0obXH11TPya-QQZxCUMzw')

      is_expected.to run.with_params(
        'am', 'am', '8.0.2', 'war', 'full'
      ).and_return('https://backstage.pingidentity.com/cloud-storage-ws/api/v1/cloudstorage/getfile/UjEs31vbQsaepHL6CrYDew')
    end
  end
end
