class MessageLogger
    def self.log(user:, message_body:, delivery_method:, reference_id: nil, status: "pending", sent_at: nil)
      DispatchMessage.create!(
        user_id: user.id,
        message_body: message_body,
        delivery_method: delivery_method,
        reference_id: reference_id,
        status: status,
        sent_at: sent_at
      )
    end
  end  