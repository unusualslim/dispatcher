require 'net/http'

module Samsara
  # JSON client for the Samsara Fleet API (https://api.samsara.com), authenticated with SAMSARA_API_KEY.
  # The token's scopes decide what works: the map only reads vehicles; routing needs Read/Write Routes,
  # Read Drivers and Read/Write Addresses.
  class Client
    BASE = 'https://api.samsara.com'.freeze
    FAILURES = [Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, OpenSSL::SSL::SSLError].freeze

    def self.configured?
      ENV['SAMSARA_API_KEY'].present?
    end

    def initialize
      raise NotConfigured, 'Samsara is not set up (SAMSARA_API_KEY is missing).' unless self.class.configured?

      @key = ENV.fetch('SAMSARA_API_KEY')
    end

    def get(path, params = {})
      request(Net::HTTP::Get, path, params: params)
    end

    def post(path, body)
      request(Net::HTTP::Post, path, body: body)
    end

    def patch(path, body)
      request(Net::HTTP::Patch, path, body: body)
    end

    # Every record of a list endpoint, following pagination.endCursor.
    def all(path, params = {})
      records = []
      cursor = nil
      loop do
        page = get(path, params.merge(cursor ? { after: cursor } : {}))
        records.concat(page['data'] || [])
        cursor = page.dig('pagination', 'endCursor')
        break unless page.dig('pagination', 'hasNextPage') && cursor.present?
      end
      records
    end

    def drivers
      all('/fleet/drivers', driverActivationStatus: 'active', limit: 512)
    end

    def addresses
      all('/addresses', limit: 512)
    end

    private

    def request(klass, path, params: {}, body: nil)
      uri = URI("#{BASE}#{path}")
      uri.query = URI.encode_www_form(params) if params.any?
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
        http.request(build_request(klass, uri, body))
      end
      parse(response)
    end

    def build_request(klass, uri, body)
      req = klass.new(uri)
      req['Authorization'] = "Bearer #{@key}"
      req['Accept'] = 'application/json'
      return req unless body

      req['Content-Type'] = 'application/json'
      req.body = body.to_json
      req
    end

    def parse(response)
      data = response.body.present? ? JSON.parse(response.body) : {}
      return data if response.is_a?(Net::HTTPSuccess)

      message = data.is_a?(Hash) ? data['message'] : nil
      raise Error, "Samsara #{response.code}: #{message.presence || response.message}#{scope_hint(response)}"
    rescue JSON::ParserError
      raise Error, "Samsara #{response.code}: unexpected response"
    end

    def scope_hint(response)
      return '' unless %w[401 403].include?(response.code)

      ' (check the API token\'s scopes in Samsara → Settings → API Tokens)'
    end
  end
end
