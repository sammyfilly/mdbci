require 'json'
require 'fileutils'
require 'uri'

require_relative 'generator'

class Session

  attr_accessor :boxes
  attr_accessor :versions
  attr_accessor :configFile
  attr_accessor :isOverride


=begin
     Load collections from json files:
      - boxes.json.json
      - versions.json
=end

  def loadCollections
    puts 'Load boxes.json'
    @boxes = JSON.parse(IO.read('boxes.json'))
    puts 'Load Versions'
  end

  def inspect
    @boxes.to_json
  end

  def setup(what)
    case what
      when 'boxes'
        p @boxes.keys
        puts 'Adding boxes to vagrant'
        p @boxes
        @boxes.each do |key, value|
          if value =~ URI::regexp
            shell = 'vagrant box add '+key+' '+value
          else
            shell = 'vagrant box add --provider virtualbox '+value
          end

          system shell
        end
      else
        puts 'Cannot setup '+what
    end
  end

  def checkConfig
    #TODO #6267
    puts 'Checking this machine configuration requirments'
    puts '.....NOT IMPLEMENTED YET'
  end

  def show(collection)
    case collection
      when 'boxes'
        puts JSON.pretty_generate(@boxes)
      when 'versions'
        puts @versions
      when 'platforms'
        puts  @boxes.keys
      else
        puts 'Unknown collection: '+collection
    end
  end

  def generate(name)
    path = Dir.pwd
    if name.nil?
      path += '/default'
    else
      path +='/'+name.to_s
    end

    p configFile
    config = JSON.parse(IO.read($session.configFile))
    puts 'Generating config in ' + path
    Generator.generate(path,config,boxes,isOverride)

  end
end