class QuoteMailer < ApplicationMailer
  default from: 'no_reply@loadntrucks.com'

  def send_quote(quote)
    @quote = quote
    mail(
      to:      quote.customer.email,
      subject: "Quote #{quote.quote_number} from Five Points Service"
    )
  end
end
