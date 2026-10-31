# frozen_string_literal: true

require 'json'
require 'openssl'
require 'securerandom'
require 'time'

module Gitflash
  module Mcp
    # The token a destructive tool hands out with its plan, and checks on the second call.
    # It is an HMAC, under a secret that lives only in this server process, of the tool, its
    # arguments, the plan and an expiry. So a token only confirms the exact change it was issued
    # for, only while the repository would still get the same plan, and only for TTL seconds.
    class Confirmation
      TTL = 300

      def initialize(secret: SecureRandom.bytes(32), clock: -> { Time.now.to_i })
        @secret = secret
        @clock = clock
      end

      def issue(tool, arguments, plan)
        expires = @clock.call + TTL
        "#{expires}.#{sign(tool, arguments, plan, expires)}"
      end

      def valid?(token, tool, arguments, plan)
        expires, mac = token.to_s.split('.', 2)
        return false unless expires&.match?(/\A\d+\z/) && mac
        return false if expires.to_i < @clock.call

        OpenSSL.fixed_length_secure_compare(mac, sign(tool, arguments, plan, expires.to_i))
      rescue ArgumentError
        false
      end

      def self.expires_at(token)
        Time.at(token.split('.', 2).first.to_i).utc.iso8601
      end

      private

      def sign(tool, arguments, plan, expires)
        OpenSSL::HMAC.hexdigest('SHA256', @secret, JSON.generate([tool, arguments, plan, expires]))
      end
    end
  end
end
