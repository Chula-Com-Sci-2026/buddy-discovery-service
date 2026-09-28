require "grpc"
require "buddy_discovery/v1/buddy_discovery_services_pb"

class BuddyDiscoveryGrpcService < BuddyDiscovery::V1::BuddyDiscoveryService::Service
  def send_buddy_request(request, _call)
    record = BuddyRequest.create!(
      sender_id: request.sender_id,
      recipient_id: request.recipient_id
    )
    serialize(record)
  rescue ActiveRecord::RecordInvalid => e
    fail_rpc(GRPC::Core::StatusCodes::INVALID_ARGUMENT, e.record.errors.full_messages.join(", "))
  rescue ActiveRecord::RecordNotUnique
    fail_rpc(GRPC::Core::StatusCodes::ALREADY_EXISTS, "a pending buddy request already exists")
  end

  def get_buddy_request(request, _call)
    serialize(find_request(request.id))
  end

  def list_buddy_requests(request, _call)
    records = BuddyRequest.involving(request.runner_id).order(created_at: :desc)
    records = records.where(status: request.status) unless request.status.empty?

    BuddyDiscovery::V1::ListBuddyRequestsResponse.new(
      buddy_requests: records.map { |record| serialize(record) }
    )
  end

  def respond_to_buddy_request(request, _call)
    record = find_request(request.id)
    fail_rpc(GRPC::Core::StatusCodes::PERMISSION_DENIED, "only the recipient can answer") if record.recipient_id != request.recipient_id

    record.respond!(request.decision)
    serialize(record)
  rescue BuddyRequest::InvalidTransition => e
    fail_rpc(GRPC::Core::StatusCodes::FAILED_PRECONDITION, e.message)
  end

  def cancel_buddy_request(request, _call)
    record = find_request(request.id)
    fail_rpc(GRPC::Core::StatusCodes::PERMISSION_DENIED, "only the sender can cancel") if record.sender_id != request.sender_id
    fail_rpc(GRPC::Core::StatusCodes::FAILED_PRECONDITION, "only pending requests can be cancelled") unless record.status == "pending"

    record.destroy!
    BuddyDiscovery::V1::CancelBuddyRequestResponse.new
  end

  private

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
      updated_at: record.updated_at.iso8601
    )
  end

  def fail_rpc(code, message)
    raise GRPC::BadStatus.new_status_exception(code, message)
  end
end
