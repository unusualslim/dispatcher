module Middleware
  # A request for a fingerprinted asset that isn't on this server (during a deploy, the old instance can get a request
  # for the new stylesheet) must not be cached: Cloudflare kept such a 404 for 4 hours and the site lost its CSS
  # (2026-11-03). Asset misses go out as no-store so the next request reaches a server that has the file.
  class NoStoreAssetMisses
    def initialize(app, prefix: '/assets/')
      @app = app
      @prefix = prefix
    end

    def call(env)
      status, headers, body = @app.call(env)
      if status.to_i == 404 && env['PATH_INFO'].to_s.start_with?(@prefix)
        headers['cache-control'] = 'no-store'
        headers.delete('expires')
      end
      [status, headers, body]
    end
  end
end
