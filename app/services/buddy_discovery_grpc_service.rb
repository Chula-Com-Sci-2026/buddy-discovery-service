require "grpc"
require "net/http"
require "json"
require "buddy_discovery/v1/buddy_discovery_services_pb"

class BuddyDiscoveryGrpcService < BuddyDiscovery::V1::BuddyDiscoveryService::Service
  def send_buddy_request(request, call)
    subject = authenticate(call)
    fail_rpc(GRPC::Core::StatusCodes::PERMISSION_DENIED, "sender must match token") unless subject == request.sender_id
    record = nil
    BuddyRequest.transaction do
      record = BuddyRequest.create!(
      sender_id: request.sender_id,
      recipient_id: request.recipient_id,
      note: request.note.strip.presence
    )
      OutboxEvent.create!(event_type: "BuddyRequestSent", payload: event_payload(record))
    end
    serialize(record)
  rescue ActiveRecord::RecordInvalid => e
    fail_rpc(GRPC::Core::StatusCodes::INVALID_ARGUMENT, e.record.errors.full_messages.join(", "))
  rescue ActiveRecord::RecordNotUnique
    fail_rpc(GRPC::Core::StatusCodes::ALREADY_EXISTS, "a pending buddy request already exists")
  end

  def get_buddy_request(request, call)
    subject = authenticate(call)
    record = find_request(request.id)
    participant!(record, subject)
    serialize(record)
  end

  def list_buddy_requests(request, call)
    subject = authenticate(call)
    fail_rpc(GRPC::Core::StatusCodes::PERMISSION_DENIED, "runner must match token") unless request.runner_id == subject
    records = BuddyRequest.involving(request.runner_id).order(created_at: :desc)
    records = records.where(status: request.status) unless request.status.empty?

    BuddyDiscovery::V1::ListBuddyRequestsResponse.new(
      buddy_requests: records.map { |record| serialize(record) }
    )
  end

  def respond_to_buddy_request(request, call)
    subject = authenticate(call)
    fail_rpc(GRPC::Core::StatusCodes::PERMISSION_DENIED, "recipient must match token") unless subject == request.recipient_id
    record = find_request(request.id)
    fail_rpc(GRPC::Core::StatusCodes::PERMISSION_DENIED, "only the recipient can answer") if record.recipient_id != request.recipient_id

    record.with_lock do
      record.respond!(request.decision)
      if record.status == "accepted"
        a, b = [ record.sender_id, record.recipient_id ].sort
        BuddyRelationship.find_or_create_by!(runner_a: a, runner_b: b)
      end
      OutboxEvent.create!(event_type: "BuddyRequestAnswered", payload: event_payload(record))
    end
    serialize(record)
  rescue BuddyRequest::InvalidTransition => e
    fail_rpc(GRPC::Core::StatusCodes::FAILED_PRECONDITION, e.message)
  end

  def cancel_buddy_request(request, call)
    subject = authenticate(call)
    fail_rpc(GRPC::Core::StatusCodes::PERMISSION_DENIED, "sender must match token") unless subject == request.sender_id
    record = find_request(request.id)
    fail_rpc(GRPC::Core::StatusCodes::PERMISSION_DENIED, "only the sender can cancel") if record.sender_id != request.sender_id
    fail_rpc(GRPC::Core::StatusCodes::FAILED_PRECONDITION, "only pending requests can be cancelled") unless record.status == "pending"

    record.destroy!
    BuddyDiscovery::V1::CancelBuddyRequestResponse.new
  end

  def search_runners(request, call)
    authenticate(call)
    uri = URI(ENV.fetch("PROFILE_URL") + "/api/v1/runners")
    uri.query = URI.encode_www_form(radiusKm: request.radius_km, experience: request.experience.empty? ? "All" : request.experience,
      pace: request.pace, availability: request.availability)
    http_request = Net::HTTP::Get.new(uri)
    http_request["Authorization"] = call.metadata["authorization"]
    response = Net::HTTP.start(uri.hostname, uri.port, open_timeout: 3, read_timeout: 5) { |http| http.request(http_request) }
    # Profile answers 404 when the caller has not saved a profile yet (running-buddy-contracts profile.openapi.json).
    fail_rpc(GRPC::Core::StatusCodes::FAILED_PRECONDITION, "Create your runner profile before searching") if response.code == "404"
    fail_rpc(GRPC::Core::StatusCodes::UNAVAILABLE, "Profile search unavailable") unless response.is_a?(Net::HTTPSuccess)
    BuddyDiscovery::V1::SearchRunnersResponse.new(runners_json: response.body.force_encoding(Encoding::UTF_8))
  rescue IOError, SystemCallError, Timeout::Error
    fail_rpc(GRPC::Core::StatusCodes::UNAVAILABLE, "Profile search unavailable")
  end

  def list_buddies(_request, call)
    subject = authenticate(call)
    relationships = BuddyRelationship.where(runner_a: subject).or(BuddyRelationship.where(runner_b: subject))
    ids = relationships.map { |row| row.runner_a == subject ? row.runner_b : row.runner_a }
    BuddyDiscovery::V1::ListBuddiesResponse.new(runner_ids: ids)
  end

  private

  def authenticate(call)
    AccessToken.subject(call.metadata["authorization"])
  rescue AccessToken::Invalid
    fail_rpc(GRPC::Core::StatusCodes::UNAUTHENTICATED, "Valid access token required")
  end

  def participant!(record, subject)
    unless [ record.sender_id, record.recipient_id ].include?(subject)
      fail_rpc(GRPC::Core::StatusCodes::PERMISSION_DENIED, "Only request participants may read it")
    end
  end

  def event_payload(record)
    { requestId: record.id, senderId: record.sender_id, recipientId: record.recipient_id, status: record.status }
  end

  def find_request(id)
    BuddyRequest.find(id)
  rescue ActiveRecord::RecordNotFound
    fail_rpc(GRPC::Core::StatusCodes::NOT_FOUND, "buddy request was not found")
  end

  def serialize(record)
    BuddyDiscovery::V1::BuddyRequest.new(
      id: record.id,
      sender_id: record.sender_id,
      recipient_id: record.recipient_id,
      status: record.status,
      created_at: record.created_at.iso8601,
      updated_at: record.updated_at.iso8601,
      note: record.note.to_s
    )
  end

  def fail_rpc(code, message)
    raise GRPC::BadStatus.new_status_exception(code, message)
  end
end
