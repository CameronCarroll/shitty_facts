require 'rubygems'
require 'light_daemon'

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
    unless last_sms_time
      send_message_and_sleep
    end

    wait_time_in_seconds = wait_time * 60 * 60
    time_difference = @last_sms_time - Time.now

    if time_difference > wait_time_in_seconds
      send_message_and_sleep
    end


    sleep 900 # Wait 900 seconds or 15 minutes before checking again
    return true # Call this function again
  end

  def send_message_and_sleep
    message = @messages[@sms_counter]
    `curl http://textbelt.com/text -d number=#{@target_number} -d "message=#{message}"`
    @last_sms_time = Time.now
    @sms_counter++
    sleep(900)
    return true
  end
end

messages = [
            "Test message 1.",
            "Test message 2."
]

target = 6193585266

wait_time = 1 #hours

our_client = SMSClient.new(target, wait_time, messages)
LightDaemon::Daemon.start(our_client, :children => 1, :pid_file => "/tmp/shitty_daemon.pid")