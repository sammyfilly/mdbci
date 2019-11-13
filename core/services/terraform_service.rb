# frozen_string_literal: true

require_relative 'shell_commands'
require_relative 'machine_configurator'
require 'net/ssh'
require 'net/scp'

# This class allows to execute commands of Terraform-cli
module TerraformService
  SSH_ATTEMPTS = 40

  def self.resource_type(provider)
    case provider
    when 'aws' then 'aws_instance'
    else raise('Unknown Terraform service provider')
    end
  end

  def self.init(logger, path = Dir.pwd)
    ShellCommands.run_command_in_dir(logger, 'terraform init', path)
  end

  def self.apply(resource, logger, path = Dir.pwd)
    ShellCommands.run_command_in_dir(logger, "terraform apply -auto-approve -target=#{resource}", path)
  end

  def self.destroy(resource, logger, path = Dir.pwd)
    ShellCommands.run_command_in_dir(logger, "terraform destroy -auto-approve -target=#{resource}", path)
  end

  def self.destroy_all(logger, path = Dir.pwd)
    ShellCommands.run_command_in_dir(logger, 'terraform destroy -auto-approve', path)
  end

  def self.fmt(logger, path = Dir.pwd)
    ShellCommands.run_command_in_dir(logger, 'terraform fmt', path)
  end

  def self.ssh_command(network_settings, command, logger)
    MachineConfigurator.new(logger).run_command(network_settings, command)
  end

  def self.ssh_available?(network_settings, logger)
    SSH_ATTEMPTS.times do
      ssh_command(network_settings, 'echo \'AVAILABLE\'', logger)
    rescue
      sleep(15)
    else
      return true
    end
    false
  end

  def self.resource_running?(resource, logger, path = Dir.pwd)
    ShellCommands.run_command_in_dir(logger, 'terraform refresh', path)
    logger.info("Check resource running state: #{resource}_running_state")
    result = ShellCommands.run_command_in_dir(logger, "terraform output #{resource}_running_state", path)
    result[:value].success? && result[:output].include?('true')
  end

  def self.resource_network(resource, logger, path = Dir.pwd)
    ShellCommands.run_command_in_dir(logger, 'terraform refresh', path)
    logger.info("Output network info: #{resource}_network")
    result = ShellCommands.run_command_in_dir(logger, "terraform output -json #{resource}_network", path)
    return Result.error('Error of terraform output network command') unless result[:value].success?

    Result.ok(JSON.parse(result[:output]))
  end
end
