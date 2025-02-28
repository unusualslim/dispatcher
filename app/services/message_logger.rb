class MessageLogger
  def self.log(dispatch, message_body, delivery_method, status, reference_id = nil)
    Rails.logger.info "Logging message with dispatch_id: #{dispatch.id}, message_body: #{message_body}, delivery_method: #{delivery_method}, status: #{status}, reference_id: #{reference_id}"
    DispatchMessage.create!(
      dispatch: dispatch,
      user: dispatch.driver,
      message_body: message_body,
      delivery_method: delivery_method,
      status: status,
      reference_id: reference_id,
      sent_at: Time.current
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to log message: #{e.message}"
    Rails.logger.error "DispatchMessage errors: #{e.record.errors.full_messages.join(', ')}"
  end
end