require 'rubygems'
require 'logger'
require 'yaml'
require 'pry'

$log = Logger.new('/home/cameron/log/shitty_facts.log')
$log.level = Logger::DEBUG

class EndOfMessagesException < StandardError
end


class SMSClient

  attr_accessor :project_name, :sms_counter, :last_sms_time, :target_number, :wait_time, :messages

  def initialize(config_file, project_name)
    configuration = load_configuration(config_file, project_name)
    project_configuration = configuration[project_name]
    if configuration
      @entire_config = configuration
      @project_name = project_name
      @project_title = project_configuration['title']
      @sms_counter = project_configuration['sms_counter']
      @last_sms_time = project_configuration['last_sms_time']
      @target_number = project_configuration['target']
      @wait_time = project_configuration['wait_time']
      @messages = project_configuration['messages']
    else
      raise ArgumentError, "couldn't load configuration file."
    end
    if project_configuration['messages'].length-1 < @sms_counter
      raise EndOfMessagesException, "couldn't find next message for project."
    end
  end

  def load_configuration(config_file, project_name)
    configuration_data = File.open(config_file, 'r') { |handle| load = YAML.load(handle) }
    if configuration_data.has_key? project_name
      return configuration_data
    else
      return nil
    end
  end

  def save_configuration(config_file)
    this_project = @entire_config[@project_name]
    this_project['sms_counter'] = @sms_counter
    this_project['last_sms_time'] = @last_sms_time

    File.open(config_file, "w") do |yaml_file|
      yaml_file.write(@entire_config.to_yaml)
    end
  end

  def check_and_send
    
    $log.debug "SMS counter: " + @sms_counter.to_s
    $log.debug "Last SMS time: " + @last_sms_time.to_s if @last_sms_time

    # if @last_sms_time exists, then it's NOT the first message.
    # We have to check whether it's been wait_time since the last message.
    if @last_sms_time
      wait_time_in_seconds = @wait_time * 60 # * 60
      time_difference = Time.now - @last_sms_time
      $log.debug "Wait time (seconds): " + wait_time_in_seconds.to_s
      $log.debug "Time difference: " + time_difference.to_s

      if time_difference.to_i > wait_time_in_seconds
        $log.debug "Time difference exceeded wait time. Sending next message to: " + @target_number.to_s
        $log.info "Message sent to: " + @target_number.to_s
        send_message
      end

    else # it is the first message.
      $log.debug "last_sms_time not found... sending first message to " + @target_number.to_s
      $log.info "Starting new project for: " + @target_number.to_s
      send_message
    end
  end

  def send_message
    message = @messages[@sms_counter]
    result = `curl http://textbelt.com/text -d number=#{@target_number} -d "message=#{message}"`
    success_result = result.split(':')[1][0..-2].chomp
    if success_result == 'true'
      @last_sms_time = Time.now
      $log.debug "Successfully sent SmS at: " + @last_sms_time.to_s
      @sms_counter = @sms_counter + 1
    else
      error = result.split(':')[2][1..-3]
      $log.error "Failed to send SMS. (Reason: " + error + ")"
    end
  end

end

$log.debug "-----------------------------------------------"
$log.debug "[Debug Log -- Called at: " + Time.now.to_s + "]"

CONFIG_FILE = "shitty.yml"
PROJECT_NAME = "project2"

begin
  our_client = SMSClient.new(CONFIG_FILE, PROJECT_NAME)
rescue ArgumentError
  $log.error "Error initializing configuration file."
  abort
rescue EndOfMessagesException
  $log.error "End of messages for this project."
  abort
else
  $log.debug "Didn't encounter any errors."
end

$log.debug "Created SMS Client successfully."

our_client.check_and_send
our_client.save_configuration(CONFIG_FILE)