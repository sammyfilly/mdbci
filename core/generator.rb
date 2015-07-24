require 'date'

require_relative '../core/out'


class Generator

  def Generator.quote(string)
    return '"'+string+'"'
  end

  def Generator.vagrantFileHeader
    vagrantFileHeader =  <<-EOF
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
    # aws.instance_type = "t1.micro"
    aws.security_groups = aws_config["security_groups"]
    aws.user_data = aws_config["user_data"]
    override.ssh.username = "ec2-user"
    override.ssh.private_key_path = aws_config["pemfile"]
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

    vagrantConfigHeader =    <<-EOF

### Vagrant configuration block  ###
####################################
Vagrant.configure(2) do |config|
EOF
  end

  def Generator.vagrantConfigFooter
    vagrantConfigFooter = "\nend   ## end of Vagrant configuration block\n"
  end

  def Generator.roleFileName(path,role)
    return path+'/'+role+'.json'
  end

  def Generator.vagrantFooter
    return "\nend # End of generated content"
  end

  def Generator.writeFile(name,content)
    IO.write(name,content)
  end

  def Generator.getVmDef(cookbook_path, name, host, boxurl, vm_mem, provisioned)

    if provisioned
      vmdef = "\n"+'config.vm.define ' + quote(name) +' do |'+ name +"|\n" \
            + "\t"+name+'.vm.box = ' + quote(boxurl) + "\n" \
            + "\t"+name+'.vm.hostname = ' + quote(host) +"\n" \
            + "\t"+name+'.vm.provision '+ quote('chef_solo')+' do |chef| '+"\n" \
            + "\t\t"+'chef.cookbooks_path = '+ quote(cookbook_path)+"\n" \
            + "\t\t"+'chef.roles_path = '+ quote('.')+"\n" \
            + "\t\t"+'chef.add_role '+ quote(name) + "\n\tend"
    else
      vmdef = "\n"+'config.vm.define ' + quote(name) +' do |'+ name +"|\n" \
            + "\t"+name+'.vm.box = ' + quote(boxurl) + "\n" \
            + "\t"+name+'.vm.hostname = ' + quote(host)
    end

    if vm_mem
      vmdef += "\n\t"+'config.vm.provider :virtualbox do |vbox|' + "\n" \
               "\t\t"+'vbox.customize ["modifyvm", :id, "--memory", ' + quote(vm_mem) +"]\n\tend\n"
    end

    vmdef += "end\n"

    return vmdef
  end
  #
  def Generator.getAWSVmDef(cookbook_path,name,boxurl,user,instance_type,provisioned)

    $out.info 'AWS: name='+name

      awsdef = 'config.vm.provider :aws do |'+ name +", override|\n" \
           + "\t"+name+'.access_key_id = aws_config["access_key_id"]' + "\n" \
           + "\t"+name+'.secret_access_key = aws_config["secret_access_key"]' + "\n" \
           + "\t"+name+'.keypair_name = aws_config["keypair_name"]' + "\n" \
           + "\t"+name+'.ami = ' + quote(boxurl) + "\n" \
           + "\t"+name+'.region = aws_config["region"]' + "\n" \
           + "\t"+name+'.instance_type = ' + quote(instance_type) + "\n" \
           + "\t"+name+'.security_groups = aws_config["security_groups"]' + "\n" \
           + "\t"+name+'.user_data = aws_config["user_data"]' + "\n" \
           + "\n" \
           + "\t"+'override.vm.box = "dummy"' + "\n" \
           + "\toverride.nfs.functional = false\n" \
           + "\t"+'override.vm.box_url = "https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box"' + "\n" \
           + "\t"+'override.ssh.username = ' + quote(user) + "\n" \
           + "\t"+'override.ssh.private_key_path = aws_config["pemfile"]' + "\n" \
           + "\n"
   if provisioned
    awsdef += "\t"+'config.vm.provision '+ quote('chef_solo')+' do |chef|' + "\n" \
           + "\t\t"+'chef.cookbooks_path = '+ quote(cookbook_path) + "\n" \
           + "\t\t"+'chef.roles_path = '+ quote('.') + "\n" \
           + "\t\t"+'chef.add_role '+ quote(name) + "\n" \
           + "\t\t"+'chef.synced_folder_type = "rsync"' + "\n\t\tend # <- end of chef block"
    end
    awsdef += "\n\tend # <- end of VM description block \n"
    return awsdef
  end

  def Generator.getRoleDef(name,package,params)

    if params.class == Hash
      mdbversion = JSON.pretty_generate(params)
    else
      mdbversion = '{ '+ "version"+':'+quote(params)+' }'
    end
    # package recipe name
    if package == 'mariadb'
      recipe_name = 'mdbc'
      #mariadb_recipe = quote('run_list') + ": [ " + quote("recipe[" + recipe_name + "]") + " ]\n"
    elsif package == 'maxscale'
      recipe_name = 'mscale'
    elsif package == 'mysql'
      recipe_name = 'msql'
    end

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

    return roledef
  end

  def Generator.checkPath(path,override)
    if Dir.exist?(path) && !override
      $out.error 'ERR: folder already exists:' + path
      $out.error 'Please specify another name or delete'
      exit -1
    end
    FileUtils.rm_rf(path)
    Dir.mkdir(path)
  end

  def Generator.boxValid?(box,boxes)
    !boxes[box].nil?
  end

  def Generator.nodeDefinition(node, boxes, path, cookbook_path)

    #??? kkv -- provisioned = true                      # default provision option
    vm_mem = nil

    $out.info node[0].to_s + ':' + node[1].to_s

    # cookbook path dir
    if node[0]['cookbook_path']
      cookbook_path = node[1].to_s
    end

    # configuration parameters
    name = node[0].to_s
    host = node[1]['hostname'].to_s

    box = node[1]['box'].to_s
    if !box.empty?
      box_params = boxes[box]
      #
      if box_params["vbox.memory"]
        vm_mem = box_params["vbox.memory"].to_s
        p "VBOX.PARAMS : " + vm_mem.to_s
      end
      #
      provider = box_params["provider"].to_s
      if provider == "aws"
        amiurl = box_params['ami'].to_s
        user = box_params['user'].to_s
        instance = box_params['default_instance_type'].to_s
      else
        boxurl = box_params['box'].to_s
      end
    end

    # package: mariadb or maxscale
    # TODO: if two or more recipes in box?
    if node[1]['mariadb']
      package = 'mariadb'
      params = node[1]['mariadb']
      provisioned = true
    elsif node[1]['maxscale']
      package = 'maxscale'
      params = node[1]['maxscale']
      provisioned = true
    elsif node[1]['mysql']
      package = 'mysql'
      params = node[1]['mysql']
      provisioned = true
    else
      provisioned = false
    end

    # generate node definition and role
    machine = ""
    if Generator.boxValid?(box,boxes)
      if provider == 'virtualbox'
        machine = getVmDef(cookbook_path,name,host,boxurl,vm_mem,provisioned)
      elsif provider == 'aws'
        machine = getAWSVmDef(cookbook_path,name,amiurl,user,instance,provisioned)
      else
        $out.warning 'WARNING: Configuration has not support AWS, config file or other vm provision'
      end
    else
      $out.warning 'WARNING: Box '+box+'is not installed or configured ->SKIPPING'
    end

    # box with mariadb, maxscale provision - create role
    if provisioned
      role = getRoleDef(name,package,params)
      IO.write(roleFileName(path,name),role)
    end

    return machine
  end

  def Generator.generate(path, config, boxes, override, aws_config)
    #TODO Errors check
    #TODO MariaDb Version Validator

    checkPath(path,override)

    cookbook_path = '../recipes/cookbooks/'  # default cookbook path
    unless (config['cookbook_path'].nil?)
      cookbook_path = config['cookbook_path']
    end


    $out.info 'Global cookbook_path=' + cookbook_path

    vagrant = File.open(path+'/Vagrantfile','w')

    vagrant.puts vagrantFileHeader

    unless(aws_config.to_s.empty?)
      # Generate AWS Configuration

      vagrant.puts Generator.awsProviderConfigImport(aws_config)
      vagrant.puts Generator.vagrantConfigHeader

      vagrant.puts Generator.awsProviderConfig

      config.each do |node|
        vagrant.puts Generator.nodeDefinition(node,boxes,path,cookbook_path)
      end

      vagrant.puts Generator.vagrantConfigFooter

    else
      # Generate VBox Configuration
      vagrant.puts Generator.vagrantConfigHeader

      vagrant.puts Generator.vboxProviderConfig

      config.each do |node|
        vagrant.puts Generator.nodeDefinition(node,boxes,path)
      end

      vagrant.puts Generator.vagrantConfigFooter
    end

    vagrant.close
  end
end
