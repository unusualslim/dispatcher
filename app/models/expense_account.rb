# Accounting → Expense Accounts: the GL expense accounts expense PO lines are charged to (Major-Sub, e.g.
# 6150-01). The site segment comes from the line's site, so a line posts as Site-Major-Sub. AP keys the
# vendor bill into PDI against these; the app doesn't post expense POs to the GL.
class ExpenseAccount < ApplicationRecord
  has_many :purchase_order_line_items, dependent: :restrict_with_error

  validates :account, presence: true, uniqueness: true,
                      format: { with: /\A\d{4}-\d{2}\z/, message: :account_format }
  validates :name, presence: true

  scope :ordered, -> { order(:account) }
  scope :active, -> { where(active: true) }

  # Active accounts plus the ones listed (a line's current choice).
  def self.selectable(keep_ids = [])
    where(active: true).or(where(id: Array(keep_ids).compact)).ordered
  end

  def label
    "#{account} #{name}"
  end
end
