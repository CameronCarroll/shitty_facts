require 'rubygems'
require 'logger'
require 'yaml'
require 'pry'

$log = Logger.new('/home/cameron/log/shitty_facts.log')
$log.level = Logger::DEBUG


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
    $log.debug "[Debug Log -- Called at: " + Time.now.to_s + "]"
    $log.debug "SMS counter: " + @sms_counter.to_s
    $log.debug "Last SMS time: " + @last_sms_time.to_s

    # if @last_sms_time exists, then it's NOT the first messages.
    # We have to check whether it's been wait_time since the last message.
    if @last_sms_time
      wait_time_in_seconds = @wait_time * 60 # * 60
      time_difference = @last_sms_time - Time.now
      $log.debug "Time difference: " + time_difference
      $log.debug "Wait time (seconds): " + wait_time_in_seconds

      if time_difference > wait_time_in_seconds then
        $log.debug "Time difference exceeded wait time. Sending next message to " + @target_number
        $log.info "Message sent to: " + @target_number
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
      $log.debug "Successfully send SmS at " + @last_sms_time.to_s
      @sms_counter = @sms_counter + 1
    else
      error = result.split(':')[2][1..-3]
      $log.debug "Failed to send SMS. Reason: " + error
      $log.error "Failed to send SMS! (" + error + ")"
    end
  end

end

CONFIG_FILE = "shitty.yml"
PROJECT_NAME = "project1"
begin
  our_client = SMSClient.new(CONFIG_FILE, PROJECT_NAME)
rescue ArgumentError
  $log.error "Failed to load configuration file."
  abort
end

$log.debug "Created SMS Client successfully."

our_client.check_and_send
our_client.save_configuration(CONFIG_FILE)