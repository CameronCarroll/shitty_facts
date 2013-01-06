require 'rubygems'
require 'light_daemon'
require 'logger'

log = Logger.new('/home/cameron/log/shitty_facts.log')
log.level = Logger::DEBUG


class SMSClient

  #(int) sms_counter -- keeps track of how many messages have been sent on this "project"
  #                     used as an index into messages for the next one to be sent.
  #(datestamp) last_sms_time -- Used to determine whether it's been wait_time since the last msg
  #(int) target_number --
  #(int: hours) wait_time -- API we're using has a 3-per-day limit to one number, so 8 hours fornow
  #(ary: string) messages -- series of messages to be sent to target_number
  attr_accessor :sms_counter, :last_sms_time, :target_number, :wait_time, :messages

  def initialize(target_number, wait_time, messages)
    @target_number = target_number
    @wait_time = wait_time
    @messages = messages
    @sms_counter = 0
  end

  def call

    File.open(logfile, 'w') do |_io|
      $stdout.reopen(_io)
      $stderr.reopen(_io)
    end

    log.debug "[Debug Log -- Called at: " + Time.now + "]"
    log.debug "SMS counter: " + @sms_counter
    log.debug "Last SMS time: " + @last_sms_time

    unless last_sms_time
      log.debug "last_sms_time not found... sending first message to " + @target_number
      send_message_and_sleep
    end

    wait_time_in_seconds = @wait_time * 60 # * 60
    time_difference = @last_sms_time - Time.now
    log.debug "Time difference: " + time_difference
    log.debug "Wait time (seconds): " + wait_time_in_seconds

    if time_difference > wait_time_in_seconds
      log.debug "Time difference exceeded wait time. Sending next message to " + @target_number
      send_message_and_sleep
    end
  end

  def send_message_and_sleep
    message = @messages[@sms_counter]
    result = `curl http://textbelt.com/text -d number=#{@target_number} -d "message=#{message}"`
    if result.split(':')[1][0..-2].chomp! == 'true'
      @last_sms_time = Time.now
      log.debug "Successfully sent SMS at " + @last_sms_time
      @sms_counter++
      sleep(60)
      return true
    else
      log.debug "Failed to send SMS. Reason: " + result.split(':')[2][1..-3]
      return false
    end

    
  end
end

messages = [
            "Hey darling, I adore you. [1]",
            "Hi again baby. You're the absolute most wonderful creature <3 :) [2]."
]

target = 6193585266

wait_time = 1 # * 60 seconds, normally x * 3600

our_client = SMSClient.new(target, wait_time, messages)
log.debug "Starting up SMSClient..."
log.debug "Target number: " + target
log.debug "Wait time (minutes): " + wait_time
LightDaemon::Daemon.start(our_client, :children => 1, :pid_file => "/tmp/shitty_daemon.pid")