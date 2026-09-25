# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'timeout'

module RedmineBsystemIntegration
  # Thin HTTP client for the three Integration Core relationship endpoints
  # (bsystem-integration-core, cmd/server/routes.go:83-126 /
  # cmd/server/relationships.go). Plain Ruby / stdlib Net::HTTP only — no
  # external gem dependency is assumed to exist in the host Redmine's
  # Gemfile.
  #
  # This client is a consumer, never a store: it holds no relationship data
  # of its own beyond the transient in-flight request/response.
  class CoreClient
    # Forward relation_type spellings accepted by Core
    # (relationships.go relationVocabulary / openapi.yaml:3258-3274).
    RELATION_TYPES = %w[
      related-to
      tests
      validates
      documents
      implements
      depends-on
      blocks
      references
    ].freeze

    RELATIONSHIPS_PATH = '/api/service/v1/relationships'

    # Base class for every error this client raises.
    class Error < StandardError; end

    # Distinct "degraded" outcome: Core could not be reached at all, or
    # replied with a 5xx. Per task requirement, timeout/connection error/5xx
    # are all folded into this single outcome so callers can render one
    # "Related Objects unavailable" state instead of crashing.
    class Unavailable < Error; end

    # A well-formed 4xx response from Core, carrying the documented error
    # envelope ({"error","code"[,"request_id"]}) so callers can show a
    # specific, actionable message (e.g. invalid_relation_type).
    class RequestError < Error
      attr_reader :status, :code, :request_id

      def initialize(message, status:, code: nil, request_id: nil)
        super(message)
        @status = status
        @code = code
        @request_id = request_id
      end
    end

    def initialize(base_url: Settings.core_base_url,
                    service_token: Settings.service_token,
                    open_timeout: Settings.open_timeout,
                    read_timeout: Settings.read_timeout)
      @base_url = base_url
      @service_token = service_token
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end

    # GET /api/service/v1/relationships?global_id=...
    # No actor/on-behalf-of token is required or accepted for this read
    # (relationships.go comment / openapi.yaml:2113-2115).
    #
    # Returns an Array of Hash, each shaped like RelationshipView:
    #   {"global_id" => "TST-000012", "relation_type" => "tested-by",
    #    "direction" => "incoming", "created_at" => "..."}
    def list_relationships(global_id:)
      uri = build_uri(RELATIONSHIPS_PATH, query: { global_id: global_id })
      response = perform(Net::HTTP::Get.new(uri))
      body = parse_json(response.body)
      Array(body && body['data'])
    end

    # POST /api/service/v1/relationships
    #
    # actor_token: the end-user bearer token resolved server-side via
    # ActorTokenResolver — never accept this from a caller that got it from
    # request params.
    #
    # Returns a Hash shaped like the Relationship schema, including "id".
    def create_relationship(from_global_id:, relation_type:, to_global_id:, actor_token:)
      uri = build_uri(RELATIONSHIPS_PATH)
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['X-On-Behalf-Of'] = "Bearer #{actor_token}"
      request.body = JSON.generate(
        from_global_id: from_global_id,
        relation_type: relation_type,
        to_global_id: to_global_id
      )
      response = perform(request)
      parse_json(response.body)
    end

    # DELETE /api/service/v1/relationships/{id}
    #
    # Always returns true on 204, per Core's documented idempotent-delete
    # contract (a replayed delete for a non-existent id is not an error).
    # This deletes only the relationship edge; it never touches either
    # endpoint object.
    def delete_relationship(id:, actor_token:)
      uri = build_uri("#{RELATIONSHIPS_PATH}/#{id}")
      request = Net::HTTP::Delete.new(uri)
      request['X-On-Behalf-Of'] = "Bearer #{actor_token}"
      perform(request)
      true
    end

    private

    def build_uri(path, query: nil)
      uri = URI.join("#{@base_url}/", path.sub(%r{\A/+}, ''))
      uri.query = URI.encode_www_form(query) if query && !query.empty?
      uri
    end

    def perform(request)
      request['Authorization'] = "Bearer #{@service_token}"
      request['Accept'] = 'application/json'

      response = http_client(request.uri).request(request)

      case response.code.to_i
      when 200..299
        response
      when 500..599
        raise Unavailable, "Core returned #{response.code}"
      else
        raise request_error(response)
      end
    rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error,
           Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH,
           SocketError, EOFError, OpenSSL::SSL::SSLError => e
      raise Unavailable, "Core unreachable: #{e.class}"
    end

    def http_client(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.open_timeout = @open_timeout
      http.read_timeout = @read_timeout
      http
    end

    def request_error(response)
      body = parse_json(response.body) || {}
      RequestError.new(
        body['error'] || "Core request failed (#{response.code})",
        status: response.code.to_i,
        code: body['code'],
        request_id: body['request_id']
      )
    end

    def parse_json(raw)
      return nil if raw.nil? || raw.empty?

      JSON.parse(raw)
    rescue JSON::ParserError
      nil
    end
  end
end
