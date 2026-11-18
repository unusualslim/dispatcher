require 'test_helper'

class ProductSdsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test 'an SDS PDF is uploaded to a product, shown and removed' do
    product = Product.create!(id: 'SDS-1', name: 'Methanol')
    sign_in User.create!(email: 'sds-admin@example.com', password: 'password123', role: 'admin')
    pdf = Rack::Test::UploadedFile.new(StringIO.new('%PDF-1.4 test'), 'application/pdf',
                                       original_filename: 'methanol-sds.pdf')

    patch sds_product_path(product), params: { file: pdf }
    assert product.reload.sds
    get product_path(product)
    assert_select 'a', text: /methanol-sds.pdf/

    patch sds_product_path(product), params: { file: Rack::Test::UploadedFile.new(StringIO.new('x'), 'text/plain', original_filename: 'a.txt') }
    assert_equal 'The SDS must be a PDF.', flash[:alert]

    patch sds_product_path(product), params: { remove: '1' }
    assert_redirected_to product_path(product)
  end
end
