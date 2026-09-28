require "test_helper"

class BuddyDiscoveryServiceTest < ActiveSupport::TestCase
  setup do
    @service = BuddyDiscoveryGrpcService.new
    @sender_id = SecureRandom.uuid
    @recipient_id = SecureRandom.uuid
  end

  test "creates and reads a buddy request" do
    created = @service.send_buddy_request(
      BuddyDiscovery::V1::SendBuddyRequestRequest.new(
        sender_id: @sender_id,
        recipient_id: @recipient_id
      ), nil
    )

    found = @service.get_buddy_request(
      BuddyDiscovery::V1::GetBuddyRequestRequest.new(id: created.id), nil
    )

    assert_equal created.id, found.id
    assert_equal "pending", found.status
  end

  test "lists requests for a runner" do
    record = BuddyRequest.create!(sender_id: @sender_id, recipient_id: @recipient_id)

    response = @service.list_buddy_requests(
      BuddyDiscovery::V1::ListBuddyRequestsRequest.new(runner_id: @recipient_id), nil
    )

    assert_equal [ record.id ], response.buddy_requests.map(&:id)
  end

  test "recipient accepts a request" do
    record = BuddyRequest.create!(sender_id: @sender_id, recipient_id: @recipient_id)

    response = @service.respond_to_buddy_request(
      BuddyDiscovery::V1::RespondToBuddyRequestRequest.new(
        id: record.id,
        recipient_id: @recipient_id,
        decision: "accepted"
      ), nil
    )

    assert_equal "accepted", response.status
  end

  test "sender cancels a pending request" do
    record = BuddyRequest.create!(sender_id: @sender_id, recipient_id: @recipient_id)

    @service.cancel_buddy_request(
      BuddyDiscovery::V1::CancelBuddyRequestRequest.new(
        id: record.id,
        sender_id: @sender_id
      ), nil
    )

    assert_not BuddyRequest.exists?(record.id)
  end

  test "rejects an unauthorized response" do
    record = BuddyRequest.create!(sender_id: @sender_id, recipient_id: @recipient_id)

    error = assert_raises(GRPC::PermissionDenied) do
      @service.respond_to_buddy_request(
        BuddyDiscovery::V1::RespondToBuddyRequestRequest.new(
          id: record.id,
          recipient_id: SecureRandom.uuid,
          decision: "accepted"
        ), nil
      )
    end

    assert_equal GRPC::Core::StatusCodes::PERMISSION_DENIED, error.code
  end
end
