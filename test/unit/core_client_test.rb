# frozen_string_literal: true
#
# Pure-Ruby unit tests for RedmineBsystemIntegration::CoreClient.
#
# Deliberately does NOT go through test/test_helper.rb (which requires a
# full Redmine application one directory level up that does not exist in
# this repository/sandbox). CoreClient itself has no Rails/Redmine
# dependency (stdlib net/http, uri, json, timeout only), so it can be
# exercised in isolation by stubbing Net::HTTP#request directly -- no
# WebMock/gem dependency required.
#
# Run (once a Ruby with minitest, which ships in stdlib, is available):
#   ruby -Ilib -Itest test/unit/core_client_test.rb

require 'minitest/autorun'
require File.expand_path('../../lib/redmine_bsystem_integration/core_client', __dir__)

# Records the last Net::HTTP request object handed to #request and lets a
# test queue up either a canned response or an exception to raise instead
# (simulating a connection failure/timeout at the socket layer).
module NetHTTPStub
  class << self
    attr_accessor :last_request, :next_response, :next_error
  end

  def self.reset!
    self.last_request = nil
    self.next_response = nil
    self.next_error = nil
  end
end

FakeResponse = Struct.new(:code, :body)

class Net::HTTP
  unless method_defined?(:bsystem_test_original_request)
    alias_method :bsystem_test_original_request, :request
  end

  def request(req)
    NetHTTPStub.last_request = req
    raise NetHTTPStub.next_error if NetHTTPStub.next_error

    NetHTTPStub.next_response
  end
end

class CoreClientTest < Minitest::Test
  BASE_URL = 'https://core.internal.example.com'
  SERVICE_TOKEN = 'svc-token-abc'

  def setup
    NetHTTPStub.reset!
    @client = RedmineBsystemIntegration::CoreClient.new(
      base_url: BASE_URL,
      service_token: SERVICE_TOKEN,
      open_timeout: 1,
      read_timeout: 1
    )
  end

  # -- list_relationships: request shape -----------------------------------

  def test_list_relationships_issues_get_to_relationships_path_with_query
    NetHTTPStub.next_response = FakeResponse.new('200', '{"data":[]}')

    @client.list_relationships(global_id: 'TSK-000042')

    req = NetHTTPStub.last_request
    assert_kind_of Net::HTTP::Get, req
    assert_equal '/api/service/v1/relationships?global_id=TSK-000042', req.uri.request_uri
  end

  def test_list_relationships_returns_parsed_data_array
    NetHTTPStub.next_response = FakeResponse.new(
      '200',
      '{"data":[{"global_id":"TST-000012","relation_type":"tested-by","direction":"incoming"}]}'
    )

    result = @client.list_relationships(global_id: 'TSK-000042')

    assert_equal(
      [{ 'global_id' => 'TST-000012', 'relation_type' => 'tested-by', 'direction' => 'incoming' }],
      result
    )
  end

  def test_list_relationships_sends_service_token_but_no_on_behalf_of_header
    # The GET/list endpoint carries no end-user identity at all (per
    # relationships.go / openapi.yaml comment cited in core_client.rb) --
    # there is no actor_token parameter on this method, and the request
    # must not carry an X-On-Behalf-Of header.
    NetHTTPStub.next_response = FakeResponse.new('200', '{"data":[]}')

    @client.list_relationships(global_id: 'TSK-000042')

    req = NetHTTPStub.last_request
    assert_equal "Bearer #{SERVICE_TOKEN}", req['Authorization']
    assert_nil req['X-On-Behalf-Of']
  end

  # -- create_relationship: request shape ----------------------------------

  def test_create_relationship_issues_post_with_correct_path_and_body
    NetHTTPStub.next_response = FakeResponse.new('201', '{"id":99,"from_global_id":"TSK-000042"}')

    @client.create_relationship(
      from_global_id: 'TSK-000042',
      relation_type: 'tests',
      to_global_id: 'TST-000012',
      actor_token: 'end-user-token'
    )

    req = NetHTTPStub.last_request
    assert_kind_of Net::HTTP::Post, req
    assert_equal '/api/service/v1/relationships', req.uri.request_uri
    assert_equal(
      { 'from_global_id' => 'TSK-000042', 'relation_type' => 'tests', 'to_global_id' => 'TST-000012' },
      JSON.parse(req.body)
    )
  end

  def test_create_relationship_returns_parsed_response_hash_including_id
    NetHTTPStub.next_response = FakeResponse.new('201', '{"id":99,"from_global_id":"TSK-000042"}')

    result = @client.create_relationship(
      from_global_id: 'TSK-000042', relation_type: 'tests', to_global_id: 'TST-000012',
      actor_token: 'end-user-token'
    )

    assert_equal 99, result['id']
  end

  # -- Anti-spoofing: the ONLY source of X-On-Behalf-Of is the actor_token
  #    keyword argument, which callers must derive server-side (see
  #    ActorTokenResolver). There is no other parameter on this method that
  #    could be substituted for it.

  def test_create_relationship_sends_service_token_as_authorization_and_actor_token_as_on_behalf_of
    NetHTTPStub.next_response = FakeResponse.new('201', '{"id":1}')

    @client.create_relationship(
      from_global_id: 'TSK-000042', relation_type: 'tests', to_global_id: 'TST-000012',
      actor_token: 'resolved-end-user-token'
    )

    req = NetHTTPStub.last_request
    assert_equal "Bearer #{SERVICE_TOKEN}", req['Authorization'],
                 'service identity must come from configured Settings, not from any per-call argument'
    assert_equal 'Bearer resolved-end-user-token', req['X-On-Behalf-Of'],
                 'on-behalf-of header must be exactly the actor_token argument, unmodified'
  end

  def test_create_relationship_has_no_parameter_that_could_carry_a_caller_supplied_identity_override
    # This is the property the task calls out explicitly: inspect the real
    # method signature (not just behavior for one input) and assert there is
    # no additional identity-shaped parameter (e.g. :on_behalf_of, :params,
    # :user_id, :token_override) a caller could use instead of actor_token.
    # If a future change added such a parameter, this test fails even before
    # anyone exercises it with a malicious value.
    params = RedmineBsystemIntegration::CoreClient.instance_method(:create_relationship).parameters
    keyword_names = params.select { |type, _| %i[key keyreq].include?(type) }.map { |_, name| name }

    assert_equal(
      %i[from_global_id relation_type to_global_id actor_token].sort,
      keyword_names.sort,
      'create_relationship must accept exactly these keywords -- no extra identity-shaped parameter'
    )
  end

  def test_create_relationship_actor_token_argument_is_the_only_thing_reflected_in_the_header
    # Vary only actor_token across two calls with otherwise-identical
    # arguments; the header must track actor_token 1:1 and nothing else
    # (e.g. a hardcoded/service-derived value leaking through, or the header
    # silently ignoring the argument).
    NetHTTPStub.next_response = FakeResponse.new('201', '{"id":1}')
    @client.create_relationship(from_global_id: 'TSK-1', relation_type: 'tests', to_global_id: 'TST-1',
                                 actor_token: 'token-A')
    header_a = NetHTTPStub.last_request['X-On-Behalf-Of']

    NetHTTPStub.next_response = FakeResponse.new('201', '{"id":2}')
    @client.create_relationship(from_global_id: 'TSK-1', relation_type: 'tests', to_global_id: 'TST-1',
                                 actor_token: 'token-B')
    header_b = NetHTTPStub.last_request['X-On-Behalf-Of']

    refute_equal header_a, header_b
    assert_equal 'Bearer token-A', header_a
    assert_equal 'Bearer token-B', header_b
  end

  # -- delete_relationship: request shape and blast radius -----------------

  def test_delete_relationship_issues_delete_to_the_given_id_path_only
    NetHTTPStub.next_response = FakeResponse.new('204', '')

    result = @client.delete_relationship(id: 77, actor_token: 'end-user-token')

    req = NetHTTPStub.last_request
    assert_kind_of Net::HTTP::Delete, req
    assert_equal '/api/service/v1/relationships/77', req.uri.request_uri
    assert_equal 'Bearer end-user-token', req['X-On-Behalf-Of']
    assert_equal true, result
  end

  def test_delete_relationship_issues_exactly_one_request_and_never_touches_an_issue_or_entity_endpoint
    NetHTTPStub.next_response = FakeResponse.new('204', '')
    calls = []
    tracker = Net::HTTP.instance_method(:request)
    Net::HTTP.define_method(:request) do |req|
      calls << req
      NetHTTPStub.last_request = req
      raise NetHTTPStub.next_error if NetHTTPStub.next_error

      NetHTTPStub.next_response
    end

    @client.delete_relationship(id: 77, actor_token: 'end-user-token')

    assert_equal 1, calls.size, 'delete must issue exactly one HTTP request'
    path = calls.first.uri.request_uri
    assert_equal '/api/service/v1/relationships/77', path
    refute_match(%r{/api/service/v1/(issues|tasks|entities)}, path)
  ensure
    Net::HTTP.define_method(:request, tracker)
  end

  # -- Distinguishing degraded (unreachable/5xx/timeout) from success/error -

  def test_5xx_response_raises_unavailable_not_request_error
    NetHTTPStub.next_response = FakeResponse.new('503', '{"error":"db down"}')

    assert_raises(RedmineBsystemIntegration::CoreClient::Unavailable) do
      @client.list_relationships(global_id: 'TSK-000042')
    end
  end

  def test_connection_refused_raises_unavailable
    NetHTTPStub.next_error = Errno::ECONNREFUSED.new

    assert_raises(RedmineBsystemIntegration::CoreClient::Unavailable) do
      @client.list_relationships(global_id: 'TSK-000042')
    end
  end

  def test_read_timeout_raises_unavailable
    NetHTTPStub.next_error = Net::ReadTimeout.new

    assert_raises(RedmineBsystemIntegration::CoreClient::Unavailable) do
      @client.list_relationships(global_id: 'TSK-000042')
    end
  end

  def test_4xx_response_raises_request_error_not_unavailable_and_preserves_envelope
    NetHTTPStub.next_response = FakeResponse.new(
      '400',
      '{"error":"invalid relation_type","code":"invalid_relation_type","request_id":"req-123"}'
    )

    err = assert_raises(RedmineBsystemIntegration::CoreClient::RequestError) do
      @client.create_relationship(from_global_id: 'TSK-1', relation_type: 'bogus', to_global_id: 'TST-1',
                                   actor_token: 'tok')
    end

    assert_equal 400, err.status
    assert_equal 'invalid_relation_type', err.code
    assert_equal 'req-123', err.request_id
    refute_kind_of RedmineBsystemIntegration::CoreClient::Unavailable, err
  end

  def test_2xx_success_returns_normally_and_does_not_raise
    NetHTTPStub.next_response = FakeResponse.new('200', '{"data":[]}')

    result = @client.list_relationships(global_id: 'TSK-000042')

    assert_equal [], result
  end
end
