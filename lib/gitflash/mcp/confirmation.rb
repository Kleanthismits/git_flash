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

      # The envelope of a plan that waits for confirmation: the dry run's, with a new token.
      # `token` is the one the call brought, if any, which did not fit.
      def required(tool, arguments, preview, token)
        note = token ? 'The confirm_token has expired or does not match this plan. ' : ''
        new_token = issue(tool.name, arguments, preview['plan'])
        message = "#{note}Review the plan; to make this change, call #{tool.name} with the " \
                  "same arguments and confirm_token #{new_token} (valid until " \
                  "#{self.class.expires_at(new_token)})."
        preview.merge('ok' => false, 'status' => 'confirmation_required', 'dry_run' => false,
                      'error' => { 'code' => 'confirmation_required', 'message' => message,
                                   'exit_code' => 2, 'confirm_token' => new_token })
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
