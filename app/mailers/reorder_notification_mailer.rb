class ReorderNotificationMailer < ApplicationMailer
  default from: 'noreply@loadntrucks.com'

  def notify(user, purchase_orders)
    @user            = user
    @purchase_orders = purchase_orders
    mail(to: user.email, subject: "#{purchase_orders.count} Draft Purchase Order(s) Created — Reorder Alert")
  end
end
