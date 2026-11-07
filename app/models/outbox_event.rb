class OutboxEvent < ApplicationRecord
  def envelope
    { eventId: id, eventType: event_type, version: 1, occurredAt: created_at.iso8601,
      correlationId: id, payload: payload }
  end
end
