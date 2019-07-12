# frozen_string_literal: true

# This class remove the product on selected node
class RemoveProductCommand < BaseCommand
  def self.synopsis
    'Remove the product on selected node.'
  end

  # This method is called whenever the command is executed
  def execute
    if @env.show_help
      show_help
      return SUCCESS_RESULT
    end
    return ARGUMENT_ERROR_RESULT unless init == SUCCESS_RESULT

    if @mdbci_config.node_names.size != 1
      @ui.error('Invalid node specified')
      return ARGUMENT_ERROR_RESULT
    end

    result = install_product(@mdbci_config.node_names.first)

    if result.success?
      SUCCESS_RESULT
    else
      ERROR_RESULT
    end
  end

  # Print brief instructions on how to use the command
  def show_help
    info = <<~HELP
      'install_product' Remove a product onto the configuration node.
      mdbci remove_product --product product --product-version version config/node
    HELP
    @ui.info(info)
  end

  # Initializes the command variable
  def init
    if @args.first.nil?
      @ui.error('Please specify the node')
      return ARGUMENT_ERROR_RESULT
    end
    @mdbci_config = Configuration.new(@args.first, @env.labels)
    @network_config = NetworkConfig.new(@mdbci_config, @ui)

    @product = @env.nodeProduct
    @product_version = @env.productVersion
    if @product.nil? || @product_version.nil?
      @ui.error('You must specify the name and version of the product')
      return ARGUMENT_ERROR_RESULT
    end

    @machine_configurator = MachineConfigurator.new(@ui)

    SUCCESS_RESULT
  end

  # Remove product on server
  # param node_name [String] name of the node
  def remove_product(name)
    role_file_path = generate_role_file(name)
    target_path = "roles/#{name}.json"
    role_file_path_config = "#{@mdbci_config.path}/#{name}-config.json"
    target_path_config = "configs/#{name}-config.json"
    extra_files = [[role_file_path, target_path], [role_file_path_config, target_path_config]]
    @network_config.add_nodes([name])
    @machine_configurator.configure(@network_config[name], "#{name}-config.json",
                                    @ui, extra_files)
  end

  # Create a role file to install the product from the chef
  # @param name [String] node name
  def generate_role_file(name)
    node = @mdbci_config.node_configurations[name]
    box = node['box'].to_s
    recipe_name = []
    recipe_name.push(@env.repos.recipe_name(@product))
    role_file_path = "#{@mdbci_config.path}/#{name}.json"
    product = { 'name' => @product, 'version' => @product_version.to_s }
    product_config = ConfigurationGenerator.generate_product_config(@env.repos, @product, product, box, nil)
    role_json_file = ConfigurationGenerator.generate_json_format(@env.box_definitions, name, product_config,
                                                                 recipe_name, box, @env.rhel_credentials)
    IO.write(role_file_path, role_json_file)
    role_file_path
  end
end
