module Samsara
  # Anything that stops a Samsara call or a route from being built; the message is shown to the user.
  class Error < StandardError; end
  class NotConfigured < Error; end
end
