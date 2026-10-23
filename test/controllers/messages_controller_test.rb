require 'test_helper'

class MessagesControllerTest < ActionDispatch::IntegrationTest
  # The webhook only answers requests signed by Twilio; see TwilioWebhookTest.
  test 'unsigned reply requests are forbidden' do
    get messages_reply_url
    assert_response :forbidden
  end
end
