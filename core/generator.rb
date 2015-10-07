require 'date'

require_relative '../core/out'


class Generator

  def Generator.quote(string)
    return '"'+string+'"'
  end

  def Generator.vagrantFileHeader
    vagrantFileHeader = <<-EOF
# !! Generated content, do not edit !!
# Generated by MariaDB Continuous Integration Tool (http://github.com/OSLL/mdbci)
# -*- mode: ruby -*-
# vi: set ft=ruby :

    EOF
    vagrantFileHeader += "\n####  Created "
    vagrantFileHeader += DateTime.now.to_s
    vagrantFileHeader += " ####\n\n"
  end

  def Generator.awsProviderConfigImport(aws_config_file)
    awsConfig = <<-EOF

### Import AWS Provider access config ###
require 'yaml'
    EOF
    awsConfig += 'aws_config = YAML.load_file(' + quote(aws_config_file.to_s) + ")['aws']\n"
    awsConfig += '## of import AWS Provider access config' + "\n"
    return awsConfig
  end

  def Generator.awsProviderConfig
    awsProviderConfig = <<-EOF

  ###           AWS Provider config block                 ###
  ###########################################################
  config.vm.box = "dummy"

  config.vm.provider :aws do |aws, override|
    aws.access_key_id = aws_config["access_key_id"]
    aws.secret_access_key = aws_config["secret_access_key"]
    aws.keypair_name = aws_config["keypair_name"]
    aws.region = aws_config["region"]
    aws.security_groups = aws_config["security_groups"]
    aws.user_data = aws_config["user_data"]
    override.ssh.private_key_path = aws_config["pemfile"]
    override.nfs.functional = false
  end ## of AWS Provider config block

    EOF
  end

  def Generator.vboxProviderConfig
    vboxConfig = <<-EOF

### Default (VBox) Provider config ###
######################################
#Network autoconfiguration
config.vm.network "private_network", type: "dhcp"

    EOF
    return vboxConfig
  end

  def Generator.vagrantConfigHeader

    vagrantConfigHeader = <<-EOF

### Vagrant configuration block  ###
####################################
Vagrant.configure(2) do |config|
    EOF
  end

  def Generator.vagrantConfigFooter
    vagrantConfigFooter = "\nend   ## end of Vagrant configuration block\n"
  end

  def Generator.roleFileName(path, role)
    return path+'/'+role+'.json'
  end

  def Generator.vagrantFooter
    return "\nend # End of generated content"
  end

  def Generator.writeFile(name, content)
    IO.write(name, content)
  end

  def Generator.getVmDef(cookbook_path, name, host, boxurl, vm_mem, template_path, provisioned)

    if provisioned
      vmdef = "\n"+'config.vm.define ' + quote(name) +' do |'+ name +"|\n" \
            + "\t"+name+'.vm.box = ' + quote(boxurl) + "\n" \
            + "\t"+name+'.vm.hostname = ' + quote(host) +"\n" \
            + "\t"+name+'.vm.synced_folder ' + quote(template_path) + ", " + quote("/home/vagrant/cnf_templates") + "\n" \
            + "\t"+name+'.vm.provision '+ quote('chef_solo')+' do |chef| '+"\n" \
            + "\t\t"+'chef.cookbooks_path = '+ quote(cookbook_path)+"\n" \
            + "\t\t"+'chef.roles_path = '+ quote('.')+"\n" \
            + "\t\t"+'chef.add_role '+ quote(name) + "\n\tend"
    else
      vmdef = "\n"+'config.vm.define ' + quote(name) +' do |'+ name +"|\n" \
            + "\t"+name+'.vm.box = ' + quote(boxurl) + "\n" \
            + "\t"+name+'.vm.hostname = ' + quote(host) + "\n" \
            + "\t"+name+'.vm.synced_folder ' + quote(template_path) + " " + quote("/home/vagrant/cnf_templates")
    end

    if vm_mem
      vmdef += "\n\t"+'config.vm.provider :virtualbox do |vbox|' + "\n" \
               "\t\t"+'vbox.customize ["modifyvm", :id, "--memory", ' + quote(vm_mem) +"]\n\tend\n"
    end

    vmdef += "\nend # <-- end of VM definition>\n"

    return vmdef
  end

  #
  def Generator.getAWSVmDef(cookbook_path, name, boxurl, user, instance_type, template_path, provisioned)

    awsdef = "config.vm.synced_folder " + quote(template_path) + ", " + quote("/home/vagrant/cnf_templates") + ", type: " + quote("rsync") + "\n" \

    awsdef += "\n#  -> Begin definition for machine: " + name +"\n"\
           + "config.vm.define :"+ name +" do |" + name + "|\n" \
           + "\t" + name + ".vm.provider :aws do |aws,override|\n" \
           + "\t\taws.ami = " + quote(boxurl) + "\n"\
           + "\t\taws.instance_type = " + quote(instance_type) + "\n" \
           + "\t\toverride.ssh.username = " + quote(user) + "\n" \
           + "\tend\n"
    if provisioned
      awsdef += "##--- Chef binding ---\n"\
           + "\t" + name + ".vm.provision "+ quote('chef_solo')+" do |chef| \n"\
           + "\t\tchef.cookbooks_path = "+ quote(cookbook_path) + "\n" \
           + "\t\tchef.roles_path = "+ quote('.') + "\n" \
           + "\t\tchef.add_role "+ quote(name) + "\n" \
           + "\t\tchef.synced_folder_type = "+quote('rsync') + "\n\tend #<-- end of chef binding\n"
  end
  awsdef +="\nend #  -> End definition for machine: " + name +"\n\n"
  return awsdef
end

def Generator.getRoleDef(name, product, box)

  errorMock = "#NONE, due invalid repo name \n"
  role = Hash.new
  productConfig = Hash.new
  product_name = nil
  repoName = nil
  repo = nil

  if !product['repo'].nil?

    repoName = product['repo']

    $out.info "Repo name: "+repoName

    unless $session.repos.knownRepo?(repoName)
      $out.warning 'Unknown key for repo '+repoName+' will be skipped'
      return errorMock
    end

    $out.info 'Repo specified ['+repoName.to_s+'] (CORRECT), other product params will be ignored'
    repo = $session.repos.getRepo(repoName)

    product_name = $session.repos.productName(repoName)
  else
    product_name = product['name']
  end

  recipe_name = $session.repos.recipeName(product_name)

  $out.info 'Recipe '+recipe_name

  if repo.nil?
    repo = $session.repos.findRepo(product_name, product, box)
  end

  if repo.nil?
    return errorMock
  end

  config = Hash.new

  config['version'] = repo['version']
  config['repo'] = repo['repo']
  config['repo_key'] = repo['repo_key']
  if !product['cnf_template'].nil?
    config['cnf_template'] = product['cnf_template']
    config['cnf_template_path'] = product['cnf_template_path']
  end
  productConfig[product_name] = config

  role['name'] = name
  role['default_attributes'] = {}
  role['override_attributes'] = productConfig
  role['json_class'] = 'Chef::Role'
  role['description'] = 'MariaDb instance install and run'
  role['chef_type'] = 'role'
  role['run_list'] = ['recipe['+recipe_name+']']

  roledef = JSON.pretty_generate(role)
  return roledef

  #todo uncomment
  if false

    # TODO: form string for several box recipes for maridb, maxscale, mysql

    roledef = '{ '+"\n"+' "name" :' + quote(name)+",\n"+ \
      <<-EOF
      "default_attributes": { },
    EOF

    roledef += " #{quote('override_attributes')}: { #{quote(package)}: #{mdbversion} },\n"

    roledef += <<-EOF
      "json_class": "Chef::Role",
      "description": "MariaDb instance install and run",
      "chef_type": "role",
    EOF
    roledef += quote('run_list') + ": [ " + quote("recipe[" + recipe_name + "]") + " ]\n"
    roledef += "}"
  end
  return roledef
end

def Generator.checkPath(path, override)
  if Dir.exist?(path) && !override
    $out.error 'ERR: folder already exists:' + path
    $out.error 'Please specify another name or delete'
    exit -1
  end
  FileUtils.rm_rf(path)
  Dir.mkdir(path)
end

def Generator.boxValid?(box, boxes)
  !boxes[box].nil?
end

def Generator.nodeDefinition(node, boxes, path, cookbook_path)

  vm_mem = node[1]['memory_size'].nil? ? '1024' : node[1]['memory_size']

  # cookbook path dir
  if node[0]['cookbook_path']
    cookbook_path = node[1].to_s
  end

  # configuration parameters
  name = node[0].to_s
  host = node[1]['hostname'].to_s

  $out.info 'Requested memory ' + vm_mem

  box = node[1]['box'].to_s
  if !box.empty?
    box_params = boxes[box]

    provider = box_params["provider"].to_s
    case provider
      when "aws"
        amiurl = box_params['ami'].to_s
        user = box_params['user'].to_s
        instance = box_params['default_instance_type'].to_s
        $out.info 'AWS definition for host:'+host+', ami:'+amiurl+', user:'+user+', instance:'+instance
      when "mdbci"
        box_params.each do |key, value|
          $session.nodes[key] = value
        end
        $out.info 'MDBCI definition for host:'+host+', with parameters: ' + $session.nodes.to_s
      else
        boxurl = box_params['box'].to_s
        p boxurl
    end
  end

  provisioned = !node[1]['product'].nil?

  if (provisioned)
    product = node[1]['product']
    template_path = product['cnf_template_path']
  end

  # generate node definition and role
  machine = ''
  if Generator.boxValid?(box, boxes)
    case provider
      when 'virtualbox'
        machine = getVmDef(cookbook_path, name, host, boxurl, vm_mem, template_path, provisioned)
      when 'aws'
        machine = getAWSVmDef(cookbook_path, name, amiurl, user, instance, template_path, provisioned)
      else
        $out.warning 'WARNING: Configuration has not support AWS, config file or other vm provision'
    end
  else
    $out.warning 'WARNING: Box '+box+'is not installed or configured ->SKIPPING'
  end

  # box with mariadb, maxscale provision - create role
  if provisioned
    $out.info 'Machine '+name+' is provisioned by '+product.to_s
    role = getRoleDef(name, product, box)
    IO.write(roleFileName(path, name), role)
  end

  return machine
end

def Generator.generate(path, config, boxes, override, aws_config)
  #TODO Errors check
  #TODO MariaDb Version Validator

  checkPath(path, override)

  cookbook_path = '../recipes/cookbooks/' # default cookbook path
  unless (config['cookbook_path'].nil?)
    cookbook_path = config['cookbook_path']
  end

  $out.info 'Global cookbook_path=' + cookbook_path

  vagrant = File.open(path+'/Vagrantfile', 'w')

  vagrant.puts vagrantFileHeader

  unless (aws_config.to_s.empty?)
    # Generate AWS Configuration
    vagrant.puts Generator.awsProviderConfigImport(aws_config)
    vagrant.puts Generator.vagrantConfigHeader

    vagrant.puts Generator.awsProviderConfig

    config.each do |node|
      $out.info 'Generate AWS Node definition for ['+node[0]+']'
      vagrant.puts Generator.nodeDefinition(node, boxes, path, cookbook_path)
    end

    vagrant.puts Generator.vagrantConfigFooter
  else
    # Generate VBox Configuration
    vagrant.puts Generator.vagrantConfigHeader
    vagrant.puts Generator.vboxProviderConfig

    config.each do |node|
      unless (node[1]['box'].nil?)
        $out.info 'Generate VBox Node definition for ['+node[0]+']'
        vagrant.puts Generator.nodeDefinition(node, boxes, path, cookbook_path)
      end
    end

    vagrant.puts Generator.vagrantConfigFooter
  end

  vagrant.close
end

end
