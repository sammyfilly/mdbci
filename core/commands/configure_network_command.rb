# frozen_string_literal: true

require_relative '../models/network_config_file'
require_relative '../services/machine_configurator'
require 'net/ssh'

# This class loads ssh keys to configuration or selected nodes.
class ConfigureNetworkCommand < BaseCommand
  # This method is called whenever the command is executed
  def execute
    if @env.show_help
      show_help
      return SUCCESS_RESULT
    end
    init
    exit_code = SUCCESS_RESULT
    nodes = @mdbci_config.node_configurations
    nodes.each do |node|
      next unless @mdbci_config.node_names.include? node[1]['hostname']

      machine = parse_node(node[1])
      code = connection(machine)
      exit_code = ERROR_RESULT if code == ERROR_RESULT
    end
    exit_code
  end

  def show_help
    info = <<-HELP
'public_keys' command allows you to copy the ssh key for the entire configuration.
You must specify the location of the ssh key using --key:
mdbci public_keys --key location/keyfile.file config

You can copy the ssh key for a specific node by specifying it with:
mdbci public_keys --key location/keyfile.file config/node

You can copy the ssh key for nodes that correspond to the selected tags:
mdbci public_keys --key location/keyfile.file --labels label config
    HELP
    @ui.info(info)
  end

  private

  # Initializes the command variable.
  def init
    raise 'Configuration name is required' if @args.nil?

    @mdbci_config = Configuration.new(@args, @env.labels)
    @keyfile = @env.keyFile
    @network_config = NetworkConfigFile.new(@mdbci_config.network_settings_file)
  end

  # Connect to the specified machine
  # @param machine [Hash] information about machine to connect
  def connection(machine)
    exit_code = SUCCESS_RESULT
    options = Net::SSH.configuration_for(machine['network'], true)
    options[:auth_methods] = %w[publickey none]
    options[:verify_host_key] = false
    options[:keys] = [machine['keyfile']]
    begin
      Net::SSH.start(machine['network'], machine['whoami'], options) do |ssh|
        upload_file(ssh)
      end
    rescue StandardError
      @ui.info "Could not connection to machine with name #{machine['name']}\n"
      exit_code = ERROR_RESULT
    end
    exit_code
  end

  # upload ssh keyfile
  # param ssh [Connection] ssh connection to use
  def upload_file(ssh)
    output = ssh.exec!('cat .ssh/authorized_keys')
    keyfile_content = File.read(@keyfile)
    if output == "cat: .ssh/authorized_keys: No such file or directory\n" || output.nil?
      ssh.scp.upload!(@keyfile, '.ssh/authorized_keys', recursive: false)
    else
      unless output.include? keyfile_content
        file = File.new(@mdbci_config.path + '_authorized_keys', 'a+')
        file.puts(output + keyfile_content)
        sh.scp.upload!(file.path, '.ssh/authorized_keys', recursive: false)
        file.close
        File.delete(file.path)
      end
    end
  end

  # Parse information about machine
  # @param node [Node] node object
  def parse_node(node)
    { 'whoami' => @network_config.configs[node['hostname']]['whoami'],
      'network' => @network_config.configs[node['hostname']]['network'],
      'keyfile' => @network_config.configs[node['hostname']]['keyfile'],
      'name' => node['hostname'] }
  end
end
