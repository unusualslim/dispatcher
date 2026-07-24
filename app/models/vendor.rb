class Vendor < ApplicationRecord
  has_many :dispatches
  has_many :purchase_orders
  has_many :product_vendors, dependent: :destroy
  has_many :products, through: :product_vendors
  has_many :vendor_freight_terms, dependent: :destroy

  validates :name, presence: true, uniqueness: true

  def freight_term_names
    vendor_freight_terms.pluck(:freight_term).sort
  end

  def sync_freight_terms!(names)
    names = Array(names).map(&:strip).reject(&:blank?).uniq
    transaction do
      vendor_freight_terms.where.not(freight_term: names).destroy_all
      names.each do |term|
        vendor_freight_terms.find_or_create_by!(freight_term: term)
      end
    end
  end
end
