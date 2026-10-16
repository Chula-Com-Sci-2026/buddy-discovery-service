require "test_helper"

class GrpcBuddyRequestsTest < ActiveSupport::TestCase
  test "creates a buddy request over the gRPC transport" do
    server = GRPC::RpcServer.new
    port = server.add_http2_port("127.0.0.1:0", :this_port_is_insecure)
    server.handle(BuddyDiscoveryGrpcService)
    server_thread = Thread.new { server.run }
    server.wait_till_running(5)

    stub = BuddyDiscovery::V1::BuddyDiscoveryService::Stub.new(
      "127.0.0.1:#{port}",
      :this_channel_is_insecure
    )
    sender = SecureRandom.uuid
    response = stub.send_buddy_request(
      BuddyDiscovery::V1::SendBuddyRequestRequest.new(
        sender_id: sender,
        recipient_id: SecureRandom.uuid
      ), metadata: { "authorization" => token_for(sender) }
    )

    assert_equal "pending", response.status
    assert BuddyRequest.exists?(response.id)
  ensure
    server&.stop
    server_thread&.join
  end
end
