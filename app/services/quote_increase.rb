# Accepts a price increase on a locked quote: a re-quote at today's rule prices, valid from the chosen date for the
# same length as the old lock, accepted at once (the old quote's lines end the day before it starts) and optionally
# emailed to the customer. Returns true when it was emailed.
class QuoteIncrease
  def initialize(quote, effective_on, user)
    @quote = quote
    @effective_on = effective_on
    @user = user
  end

  def run!(email: false)
    requote = nil
    Quote.transaction do
      requote = @quote.create_requote!(QuoteMarginReview.for_quote(@quote))
      note = "Price increase effective #{@effective_on.strftime('%m/%d/%Y')}."
      requote.update!(valid_from: @effective_on, expiry_date: @effective_on + lock_days,
                      notes: [requote.notes, note].join("\n"))
      requote.accept!(@user)
    end
    email && emailed?(requote)
  end

  private

  def lock_days
    @quote.valid_from && @quote.expiry_date ? (@quote.expiry_date - @quote.valid_from).to_i : 29
  end

  # Emails the re-quote to the customer when they have an address; true when sent.
  def emailed?(requote)
    return false if requote.customer&.email.blank?

    QuoteMailer.send_quote(requote).deliver_later
    requote.update!(sent_at: Time.current)
    true
  end
end
