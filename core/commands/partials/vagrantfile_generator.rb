# frozen_string_literal: true

require 'date'
require 'fileutils'
require 'json'
require 'pathname'
require 'securerandom'
require 'socket'
require 'erb'
require 'set'
require_relative '../base_command'
require_relative '../../out'
require_relative '../../models/configuration.rb'
require_relative '../../services/shell_commands'
require_relative '../../../core/services/configuration_generator'

# The class generates the Vagrantfile content for MDBCI configuration
class VagrantfileGenerator
  CONFIGURATION_FILE_NAME = 'Vagrantfile'

  # Initializer
  # @param logger [Out] logger
  # @param ipv6 [Boolean] need for ipv6 for VM.
  def initialize(logger, ipv6)
    @ui = logger
    @ipv6 = ipv6
  end

  def configuration_file_name
    CONFIGURATION_FILE_NAME
  end

  # Header of generated configuration file
  def file_header
    <<-HEADER
# !! Generated content, do not edit !!
# Generated by MariaDB Continuous Integration Tool (https://github.com/mariadb-corporation/mdbci)
#### Created #{Time.now} ####
    HEADER
  end

  # Header of configuration content
  def config_header
    <<-HEADER
### Vagrant configuration block  ###
####################################
Vagrant.configure(2) do |config|
    HEADER
  end

  # Footer of configuration content
  def config_footer
    <<-FOOTER
end
### end of Vagrant configuration block
    FOOTER
  end

  # Generate and return provider configuration content for configuration file
  # @param _path [String] path of the generated configuration
  # @return [String] provider configuration content for configuration file
  def generate_provider_config(_path)
    @ui.info('Generating libvirt/VirtualBox configuration')
    provider_config
  end

  # Generate the key pair for the AWS.
  def handle_invalid_configuration_case() end

  # Print node info specific for current nodes provider
  def print_node_specific_info(_node_params) end

  # Generate a node definition for the Vagrantfile, depending on the provider
  # uses the appropriate generation method.
  #
  # @param node_params [Hash] list of the node parameters
  # @param path [String] path of the configuration file
  # @return [String] node definition for the Vagrantfile.
  def generate_node_defenition(node_params, path)
    case node_params[:provider]
    when 'virtualbox'
      get_virtualbox_definition(node_params)
    when 'libvirt'
      get_libvirt_definition(path, node_params)
    else
      @ui.warning('Configuration type invalid! It must be vbox, aws or libvirt type. Check it, please!')
      ''
    end
  end

  private

  def provider_config
    <<-CONFIG
### Default (VBox, Libvirt) Provider config ###
#######################################################
# Network autoconfiguration
config.vm.network "private_network", type: "dhcp"
config.vm.boot_timeout = 60
    CONFIG
  end

  # Generate Vagrant configuration of VM box for VirtualBox provider
  # @param node_params [Hash] list of the node parameters
  # @return [String] configuration content of VM box
  # rubocop:disable Metrics/MethodLength
  def get_virtualbox_definition(node_params)
    template = ERB.new <<-VBOX
      config.vm.define '<%= name %>' do |box|
        box.vm.box = '<%= box %>'
        box.vm.hostname = '<%= host %>'
        <% if ssh_pty %>
           box.ssh.pty = <%= ssh_pty %>
        <% end %>
        <% if template_path %>
           box.vm.synced_folder '<%= template_path %>', '/home/vagrant/cnf_templates'
        <% end %>
        box.vm.provider :virtualbox do |vbox|
          <% if vm_mem %>
             vbox.memory = <%= vm_mem %>
          <% end %>
          vbox.name = "\#{File.basename(File.dirname(__FILE__))}_<%= name %>"
        end
      end
    VBOX
    template.result(OpenStruct.new(node_params).instance_eval { binding })
  end
  # rubocop:enable Metrics/MethodLength

  # Generate Vagrant configuration of VM box for libvirt provider
  # @param path [Hash] path of the configuration file
  # @param node_params [Hash] list of the node parameters
  # @return [String] configuration content of VM box
  # rubocop:disable Metrics/MethodLength
  def get_libvirt_definition(path, node_params)
    node_params = node_params.merge(expand_path: File.expand_path(path), ipv6: @ipv6)
    template = ERB.new <<-LIBVIRT
      #  --> Begin definition for machine: <%= name %>
      config.vm.define '<%= name %>' do |box|
        box.vm.box = '<%= box %>'
        box.vm.hostname = '<%= host %>'
        <% if ssh_pty %>
          box.ssh.pty = <%= ssh_pty %>
        <% end %>
        <% if template_path %>
          box.vm.synced_folder '<%= template_path %>', '/home/vagrant/cnf_templates', type:'rsync'
        <% end %>
        box.vm.synced_folder '<%= expand_path %>', '/vagrant', type: 'rsync'
        <% if ipv6 %>
          box.vm.network :public_network, :dev => 'virbr0', :mode => 'bridge', :type => 'bridge'
        <% end %>
        box.vm.provider :libvirt do |qemu|
          qemu.driver = 'kvm'
          qemu.cpu_mode = 'host-passthrough'
          qemu.cpus = <%= vm_cpu %>
          qemu.memory = <%= vm_mem %>
        end
        <% if platform == 'ubuntu' && platform_version == 'bionic' %>
        # Fix DNS bug
        script = <<-SCRIPT
          echo Fixing the netplan configuration
          sed -i '/nameservers:/d' /etc/netplan/01-netcfg.yaml
          sed -i '/addresses:/d' /etc/netplan/01-netcfg.yaml
          netplan apply
          echo Fixing systemd-resolved configuration
          echo "
[Resolve]
DNS=1.1.1.1
FallbackDNS=
Domains=
LLMNR=no
MulticastDNS=no
DNSSEC=no
Cache=no
DNSStubListener=yes" > /etc/systemd/resolved.conf
          systemctl restart systemd-resolved
          systemd-resolve --status
        SCRIPT

        box.vm.provision "shell", inline: script
        <% end %>
      end #  <-- End of Qemu definition for machine: <%= name %>
    LIBVIRT
    template.result(OpenStruct.new(node_params).instance_eval { binding })
  end
  # rubocop:enable Metrics/MethodLength
end
