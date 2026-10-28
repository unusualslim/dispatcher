# Stands in for Samsara::Client: canned drivers/addresses/routes, records writes.
class FakeSamsaraClient
  attr_reader :posts, :patches, :drivers, :addresses
  attr_accessor :routes

  def initialize(drivers:, addresses:)
    @drivers = drivers
    @addresses = addresses
    @posts = []
    @patches = []
    @routes = {}
  end

  def get(path, _params = {})
    route = @routes[path.split('/').last]
    raise Samsara::Error, 'Samsara 404: route not found' unless route

    { 'data' => route }
  end

  def post(path, body)
    @posts << [path, body]
    { 'data' => { 'id' => path == '/addresses' ? "addr-new-#{@posts.size}" : 'route-1' } }
  end

  def patch(path, body)
    @patches << [path, body]
    { 'data' => { 'id' => path.split('/').last } }
  end
end
