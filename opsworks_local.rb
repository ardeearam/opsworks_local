#Author: Ardee Aram
#I was thinking of doing this the ruby version via gem 'aws-sdk', but it may bork up during OpsWorks and cron operations.
#By not using any gems, this ruby script can be placed and run virtually anywhere. 
#I don't want to write this on pure bash, as I will miss the wonderful ruby syntax.
#Make sure aws-cli is installed, and properly configured.

require 'json'
require 'optparse'

class OpsworksLocal
  
  def run
    begin      
       get_options!    
      
       #Display options help if there are no options.
       raise "" if @options.empty? 
    
        aws_opsworks = "aws opsworks --region us-east-1"
        
        #Introspection: by default, the target instance is the current instance.
        #Catch: won't work on non-EC2 instances, e.g. development machine.
        #http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html
        begin
          ec2_instance_ids = @options[:instance_ids] || [`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`] 
        rescue
          #If run in non-ec2 instances, where the wget won't really work.
          ec2_instance_ids = []
        end
          
        def aws_json(json)
          JSON.parse(json,{:symbolize_names => true})
        end
        
        stacks = aws_json(`#{aws_opsworks} describe-stacks`)
        @opsworks_ids = []            #available instances in all of OpsWorks
        @stack_ids = []               #available stacks in all of OpsWorks
        app_ids = []
        
        stacks[:Stacks].each do |stack|
                    
          stack_id = stack[:StackId]
          @stack_ids << {stack_id: stack_id, name: stack[:Name]}
          
          #Get stacks where the particular EC2 instance belong.
          instances = aws_json(`#{aws_opsworks} describe-instances --stack-id #{stack_id}`)          
          instances[:Instances].each do |instance|
                next if !ec2_instance_ids.include?(instance[:Ec2InstanceId])
                @opsworks_ids << {stack_id: stack_id, opsworks_instance_id: instance[:InstanceId]}
          end
        
          #Get App ID's of the said stacks (only on deployment)
          if @options[:command].to_sym == :deploy
            apps = aws_json(`#{aws_opsworks} describe-apps --stack-id #{stack_id}`)  
          apps[:Apps].each do |app|
            app_ids << {stack_id: stack_id, app_id: app[:AppId], name: app[:Name]}
          end
          end
        end
        
        
        
           #Assume the arguments are valid recipes
           #An instance may be a member of more than one stack
           case @options[:command].to_sym
           when :execute_recipes  
              recipes = @options[:recipes].map{|x| %Q(\\"#{x}\\")}.join(",")
              args =  %Q(, \\"Args\\":{\\"recipes\\":[#{recipes}]})  
              app_id = ""
           when :deploy
              args = ""
          
           else
              args = ""
              app_id = ""
           end
        
         
        
           #execution time!
           #For each stack...
           target_stacks.each do |stack_id|
        
            #... get the instance_ids associated with this stack...
            instance_ids = ""
            if !@options[:all_instances] && @opsworks_ids.count > 0 
              instance_ids = "--instance-ids #{@opsworks_ids.select{|x| x[:stack_id] == stack_id}.map{|x| x[:opsworks_instance_id]}.join(' ')}" 
            end
            
            create_deployment = lambda do |args, app_id|  
              puts (`#{aws_opsworks} create-deployment --stack-id #{stack_id} #{instance_ids} --command "{\\"Name\\":\\"#{@options[:command]}\\" #{args}}" #{app_id}`)
            end
        
            case @options[:command].to_sym
            when :deploy
                #Deploy all apps present in stacks where the instance is registered.
                app_ids.select{|x| x[:stack_id] == stack_id}.each do |app|
                  puts app
                  create_deployment.call(args, "--app-id #{app[:app_id]}")
                end 
            else
                create_deployment.call(args, app_id)  
            end
           end
    
    rescue StandardError => ex
       puts ex.message if !ex.message.empty? 
       puts @option_parser
    end    
  end

  private  
  
  # Get command line options
  def get_options!
    @options = {}
    @option_parser = OptionParser.new do |opts|
      opts.banner =  "Usage: opsworks_local.rb [options]"
            opts.on("-c", "--command COMMAND",[:execute_recipes, :setup, :configure, :deploy, :undeploy, :shutdown, :update_custom_cookbooks], "Run an OpsWorks command. Available commands are:",
        "* execute_recipes",
                    "* setup",
                    "* configure",
                    "* deploy",
                    "* undeploy",
                    "* shutdown",
                    "* update_custom_cookbooks",
                    "Defaults to 'execute_recipes'\n"
                 
            
        ) do |command|
        @options[:command] = command 
      end 
      opts.on("-r", "--recipes RECIPE1,...", Array, "Execute a series of custom recipes (without spaces).", 
        "When used, this ignores the -c switch, and assumes the command of 'execute_recipes'") do |recipes| 
        @options[:recipes] = recipes 
      end 
      
      opts.on("-i", "--instance-ids INSTANCEID1,...",Array, "If given, the EC2 instance ids where the command will be run (comma separeted, without spaces). Defaults to the current server where this script is executed.") do |instance_ids|
        @options[:instance_ids] = instance_ids
      end
      
      opts.on("-a", "--all-instances", "Apply command for all instances on the stack of this instance. This overrides the -i switch.") do
        @options[:all_instances] = true
      end
      
      opts.on("-s", "--stack STACK_NAME", "Execute command on all instances for a stack. Argument should be the short name of the stack. This automatically sets the -a flag.") do |stack|
        @options[:stack] = stack
      end
      
      opts.on("-h", "--help", "Show this message.") do
        @options[:help] = true
        puts opts
      end
    end
    
    @option_parser.parse!    
    override_options!        
  end
  
  #This arbitrates if there are conflicting switches used.
  def override_options!
    
    #-r overrides -c
    if !@options[:recipes].nil?
      @options[:command] = :execute_recipes
    end
    
    #-s sets -a to true.
    if !@options[:stack].nil?
      @options[:all_instances] = true
    end
    
    #-a overrides -i
    if @options[:all_instances] === true
      @options[:instance_ids] = nil
    end
  end
  
  #This returns the target stack, depending on the flags set.
  def target_stacks
    if @options[:stack].nil?
      #Extract stack from available instances
      @opsworks_ids.map{|x| x[:stack_id]}.uniq
    else
      #Lookup stack id from given
     @stack_ids.select{|x| x[:name].downcase == @options[:stack].downcase}.map{|x| x[:stack_id]}
    end
  end
  
end

#Run time!
#Neat trick: http://stackoverflow.com/questions/8990790/run-code-only-if-script-called-from-the-command-line
OpsworksLocal.new.run if __FILE__==$0

