require 'test_helper'
require Rails.root.join('lib/middleware/no_store_asset_misses').to_s

class NoStoreAssetMissesTest < ActiveSupport::TestCase
  def call(status, path)
    app = ->(_env) { [status, { 'content-type' => 'text/html', 'expires' => 'later' }, ['x']] }
    Middleware::NoStoreAssetMisses.new(app).call('PATH_INFO' => path)
  end

  test 'a missing asset is sent as no-store' do
    _, headers, = call(404, '/assets/application-abc123.css')
    assert_equal 'no-store', headers['cache-control']
    assert_nil headers['expires']
  end

  test 'found assets and other 404s are left alone' do
    assert_nil call(200, '/assets/application-abc123.css')[1]['cache-control']
    assert_nil call(404, '/locations/999')[1]['cache-control']
  end
end
