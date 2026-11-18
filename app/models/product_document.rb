# A file kept for a product: today its safety data sheet (kind "sds"). See CreateProductDocuments for why the file
# hangs off this record and not the product.
class ProductDocument < ApplicationRecord
  KINDS = { 'sds' => 'Safety data sheet' }.freeze

  belongs_to :product
  has_one_attached :file

  validates :kind, inclusion: { in: KINDS.keys }, uniqueness: { scope: :product_id }
end
