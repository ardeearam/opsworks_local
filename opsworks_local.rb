#Author: Ardee Aram
#I was thinking of doing this the ruby version via gem 'aws-sdk', but it may bork up during OpsWorks and cron operations.
#By not using any gems, this ruby script can be placed and run virtually anywhere. 
#I don't want to write this on pure bash, as I will miss the wonderful ruby syntax.
#Make sure aws-cli is installed, and properly configured.

require 'json'
require 'optparse'

credentials ||=""


options = {}
option_parser = OptionParser.new do |opts|
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
		options[:command] = command 
	end 
	opts.on("-r", "--recipes RECIPE1,...", Array, "Execute a series of custom recipes (without spaces).", 
		"When used, this ignores the -c switch, and assumes the command of 'execute_recipes'") do |recipes| 
		options[:command] = :execute_recipes
		options[:recipes] = recipes 
	end 
	opts.on("-i", "--instance-id INSTANCEID", "If given, the EC2 instance id where the command will be run. Defaults to the current server where this script is executed.") do |instance_id|
		options[:instance_id] = instance_id
	end
        opts.on("-h", "--help", "Show this message.") do
		options[:help] = true
        	puts opts
	end
end

begin
   option_parser.parse!

   raise "" if options.empty?	

aws_opsworks = "aws opsworks --region us-east-1"
#http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html
ec2_instance_id = options[:instance_id] || `wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`
recipe =
def aws_json(json)
  JSON.parse(json,{:symbolize_names => true})
end

stacks = aws_json(`#{credentials} #{aws_opsworks} describe-stacks`)
opsworks_ids = []
app_ids = []
stacks[:Stacks].each do |stack|
  stack_id = stack[:StackId]
  instances = aws_json(`#{credentials} #{aws_opsworks} describe-instances --stack-id #{stack_id}`)

  instances[:Instances].each do |instance|
        next if instance[:Ec2InstanceId] != ec2_instance_id
        opsworks_ids << {stack_id: stack_id, opsworks_instance_id: instance[:InstanceId]}
  end

  #Get App ID's only on deployment
  if options[:command].to_sym == :deploy
  	apps = aws_json(`#{credentials} #{aws_opsworks} describe-apps --stack-id #{stack_id}`) 	
	apps[:Apps].each do |app|
		app_ids << {stack_id: stack_id, app_id: app[:AppId], name: app[:Name]}
	end
  end
end



   #Assume the arguments are valid recipes
   #An instance may be a member of more than one stack
   case options[:command].to_sym
   when :execute_recipes  
   	recipes = options[:recipes].map{|x| %Q(\\"#{x}\\")}.join(",")
        args =  %Q(, \\"Args\\":{\\"recipes\\":[#{recipes}]})  
        app_id = ""
   when :deploy
	args = ""
	
   else
	args = ""
        app_id = ""
   end

   #execution time
   opsworks_ids.each do |opswork|

    create_deployment = lambda do |args, app_id| 	

	    puts (`#{credentials} #{aws_opsworks} create-deployment --stack-id #{opswork[:stack_id]} --instance-ids #{opswork[:opsworks_instance_id]} --command "{\\"Name\\":\\"#{options[:command]}\\" #{args}}" #{app_id}`)
    end

    case options[:command].to_sym
    when :deploy
	#Deploy all apps present in stacks where the instance is registered.
	app_ids.select{|x| x[:stack_id] == opswork[:stack_id]}.each do |app|
		puts app
		create_deployment.call(args, "--app-id #{app[:app_id]}")
        end	
    else
	create_deployment.call(args, app_id) 	
    end

   end

rescue StandardError => ex
   puts ex.message if !ex.message.empty? 
   puts option_parser
end


