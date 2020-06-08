# frozen_string_literal: true

require_relative 'parse_helper'

# This module handles the Galera Enterprise CI repository
module GaleraEnterpriseCiParser
  def self.parse(config, mdbe_ci_config, log, logger)
    return [] if mdbe_ci_config.nil?

    auth = mdbe_ci_config['mdbe_ci_repo']
    releases = []
    releases.concat(
      parse_galera_enterprise_ci_rpm_repository(config['repo']['rpm'], auth, log, logger)
    )
    releases.concat(
      parse_galera_enterprise_ci_deb_repository(config['repo']['deb'], auth, log, logger)
    )
    releases
  end

  def self.parse_galera_enterprise_ci_rpm_repository(config, auth, log, logger)
    ParseHelper.parse_repository(
      config['path'], auth, ParseHelper.add_auth_to_url(config['key'], auth),
      'galera_enterprise_ci', %w[galera-enterprise],
      ->(url) { url }, ->(package, _) { /#{package}/ },
      log, logger,
      ParseHelper.save_as_field(:version),
      save_url_to_field(:release_root),
      ParseHelper.append_url(%w[yum]),
      ParseHelper.split_rpm_platforms,
      ParseHelper.extract_field(:platform_version, %r{^(\p{Digit}+)\/?$}),
      lambda do |release, _|
        release[:repo] = ParseHelper.add_auth_to_url(release[:url], auth)
        release
      end
    )
  end

  def self.parse_galera_enterprise_ci_deb_repository(config, auth, log, logger)
    ParseHelper.parse_repository(
      config['path'], auth, ParseHelper.add_auth_to_url(config['key'], auth),
      'galera_enterprise_ci', %w[galera-enterprise],
      ->(url) { generate_galera_ci_deb_full_url(url) },
      ->(package, platform) { /#{package}.*#{platform}/ }, log, logger,
      ParseHelper.save_as_field(:version),
      save_url_to_field(:release_root),
      ParseHelper.append_url(%w[apt], nil, true),
      ParseHelper.append_url(%w[dists]), ParseHelper.extract_deb_platforms,
      lambda do |release, _|
        repo_path = ParseHelper.add_auth_to_url(release[:repo_url], auth)
        release[:repo] = "#{repo_path} #{release[:platform_version]} main"
        release
      end
    )
  end

  def self.generate_galera_ci_deb_full_url(incorrect_url)
    split_url = incorrect_url.split('/')
    split_url.pop(2)
    url = split_url.join('/')
    "#{url}/pool/main/g/galera-enterprise-4/"
  end

  # Save URL to the key
  # @param key [Symbol] field to save data to
  def self.save_url_to_field(key)
    lambda do |release, _links|
      [release.clone.merge({ key => release[:url] })]
    end
  end
end
