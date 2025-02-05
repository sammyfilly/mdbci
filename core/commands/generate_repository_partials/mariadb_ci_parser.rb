# frozen_string_literal: true

require_relative 'repository_parser_core'

# This module handles the MariaDB CI repository
module MariadbCiParser
  extend RepositoryParserCore

  def self.parse(config, product_version, mdbe_ci_config, log, logger)
    return [] if mdbe_ci_config.nil?

    auth_mdbe_ci_repo = mdbe_ci_config['mdbe_ci_repo']
    releases = []
    releases.concat(
      parse_mariadb_ci_rpm_repository(config['repo'], product_version, auth_mdbe_ci_repo, log,
                                      logger)
    )
    releases.concat(
      parse_mariadb_ci_deb_repository(config['repo'], product_version, auth_mdbe_ci_repo, log,
                                      logger)
    )
    releases
  end

  def self.parse_mariadb_ci_rpm_repository(config, product_version, auth, log, logger)
    parse_repository(
      config['path'], auth, nil, 'mariadb_ci', product_version,
      %w[MariaDB-client MariaDB-server],
      ->(url, _) { url },
      ->(package, _) { /#{package}/ },
      log, logger,
      save_as_field(:version),
      save_key(logger, auth, add_auth_to_url(config['key'], auth)),
      split_rpm_platforms,
      extract_field(:platform_version, %r{^(\p{Digit}+)/?$}),
      append_url(%w[x86_64 aarch64], :architecture),
      lambda do |release, _|
        release[:repo] = add_auth_to_url(release[:url], auth)
        release
      end
    )
  end

  def self.parse_mariadb_ci_deb_repository(config, product_version, auth, log, logger)
    parse_repository(
      config['path'], auth, nil, 'mariadb_ci', product_version,
      %w[mariadb-client mariadb-server],
      ->(url, _) { generate_mariadb_ci_deb_full_url(url, logger, auth) },
      ->(package, _) { /#{package}/ }, log, logger,
      save_as_field(:version),
      save_key(logger, auth, add_auth_to_url(config['key'], auth)),
      append_url(%w[apt], nil, true),
      append_url(%w[dists]),
      extract_deb_platforms,
      set_deb_architecture(auth),
      lambda do |release, _|
        repo_path = add_auth_to_url(release[:repo_url], auth)
        release[:repo] = "#{repo_path} #{release[:platform_version]} main"
        release
      end
    )
  end
end
