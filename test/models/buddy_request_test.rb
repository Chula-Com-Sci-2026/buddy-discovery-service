require "test_helper"

class BuddyRequestTest < ActiveSupport::TestCase
  test "does not allow a request to oneself" do
    runner_id = SecureRandom.uuid
    request = BuddyRequest.new(sender_id: runner_id, recipient_id: runner_id)

    assert_not request.valid?
    assert_includes request.errors[:recipient_id], "cannot be the sender"
  end

  test "keeps the note to 180 characters" do
    request = BuddyRequest.new(sender_id: SecureRandom.uuid, recipient_id: SecureRandom.uuid, note: "a" * 181)

    assert_not request.valid?
    assert request.errors[:note].any?
  end

  test "accepts a pending request" do
    request = BuddyRequest.create!(valid_attributes)

    request.respond!("accepted")

    assert_equal "accepted", request.status
  end

  test "does not answer an accepted request again" do
    request = BuddyRequest.create!(valid_attributes.merge(status: "accepted"))

    assert_raises(BuddyRequest::InvalidTransition) { request.respond!("rejected") }
  end

  private

  def valid_attributes
    { sender_id: SecureRandom.uuid, recipient_id: SecureRandom.uuid }
  end
end
