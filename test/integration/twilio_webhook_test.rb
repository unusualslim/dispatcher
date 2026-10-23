require 'test_helper'
require 'minitest/mock'

# The SMS reply webhook is public; it must only act on requests signed by Twilio.
class TwilioWebhookTest < ActionDispatch::IntegrationTest
  TOKEN = 'test-twilio-auth-token'.freeze

  # From a number with no matching user, so a valid request stops before sending an SMS.
  PARAMS = { 'From' => '+15550000000', 'Body' => 'hi' }.freeze

  def signature_for(url, params)
    Twilio::Security::RequestValidator.new(TOKEN).build_signature_for(url, params)
  end

  def with_twilio_token(&)
    Rails.application.credentials.stub(:twilio_token, TOKEN, &)
  end

  test 'rejects requests without a Twilio signature' do
    with_twilio_token do
      post reply_messages_path, params: PARAMS
    end
    assert_response :forbidden
  end

  test 'rejects requests with a forged signature' do
    with_twilio_token do
      post reply_messages_path, params: PARAMS, headers: { 'X-Twilio-Signature' => 'forged' }
    end
    assert_response :forbidden
  end

  test 'accepts requests signed with the auth token' do
    signature = signature_for("http://www.example.com#{reply_messages_path}", PARAMS)
    with_twilio_token do
      post reply_messages_path, params: PARAMS, headers: { 'X-Twilio-Signature' => signature }
    end
    assert_not_equal 403, response.status
  end
end
