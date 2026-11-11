class BuddyRequest < ApplicationRecord
  STATUSES = %w[pending accepted rejected].freeze

  validates :sender_id, :recipient_id, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :note, length: { maximum: 180 }
  validates :recipient_id, uniqueness: {
    scope: :sender_id,
    conditions: -> { where(status: "pending") },
    message: "already has a pending request from this runner"
  }
  validate :participants_must_differ

  scope :involving, lambda { |runner_id|
    where(sender_id: runner_id).or(where(recipient_id: runner_id))
  }

  def respond!(decision)
    raise InvalidTransition, "only pending requests can be answered" unless status == "pending"
    raise InvalidTransition, "decision must be accepted or rejected" unless %w[accepted rejected].include?(decision)

    update!(status: decision)
  end

  private

  def participants_must_differ
    errors.add(:recipient_id, "cannot be the sender") if sender_id == recipient_id
  end

  class InvalidTransition < StandardError; end
end
