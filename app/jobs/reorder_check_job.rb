class ReorderCheckJob < ApplicationJob
  queue_as :default

  def perform
    created = ReorderService.run
    if created.any?
      User.where(role: %w[admin manager]).each do |user|
        next unless user.email_opt_in
        ReorderNotificationMailer.notify(user, created).deliver_later
      end
    end
  end
end
