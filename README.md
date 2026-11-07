# Buddy Discovery Service

Buddy Discovery Service is a gRPC microservice for the **Can't Run Alone** platform. It owns runner discovery, buddy requests, buddy relationships, blocking, and the candidate projection used for searching. The Deliverable 3 request lifecycle is extended for Deliverable 4 with authenticated search, buddy relationships and broker-backed notifications.

## Current scope

The implemented gRPC operations provide CRUD-equivalent behavior:

| CRUD action | RPC | Behavior |
| --- | --- | --- |
| Create | `SendBuddyRequest` | Create a pending request |
| Read | `GetBuddyRequest` | Read one request |
| Read | `ListBuddyRequests` | List requests involving a runner |
| Update | `RespondToBuddyRequest` | Accept or reject a pending request |
| Delete | `CancelBuddyRequest` | Cancel and delete a pending request |

The service prevents self-requests, duplicate pending requests, unauthorized responses, unauthorized cancellation, and repeated responses.

Runner search delegates to the Profile API through `SearchRunners`; `ListBuddies` reads persisted relationships. Every RPC validates the JWT and resource ownership. Request creation/response writes a transactional outbox consumed by `bin/outbox-worker`, which publishes persistent RabbitMQ events. Blocking, PostGIS candidate projections, Kafka integration and expiration jobs remain deferred.

## Technology

- Ruby 3.4.12
- Rails 8.1.4 in API-only mode
- gRPC Ruby 1.84.0 and Protocol Buffers
- PostgreSQL 16
- Minitest
- Docker Compose

## Contract

The source-of-truth Protocol Buffers contract is:

```text
proto/buddy_discovery/v1/buddy_discovery.proto
```

The package and service name is:

```text
buddy_discovery.v1.BuddyDiscoveryService
```

Generated Ruby messages and service stubs are checked into `lib/buddy_discovery/v1/` so consumers and CI do not need to regenerate them.

## Deliverable 4 integration and tests

Use `../running-buddy-integration/README.md` for the full stack, generated local secrets, demo seeds, contract exports and all-service tests. JWT authorization is now required, including direct gRPC calls through `authorization: Bearer <token>` metadata. Set `JWT_SECRET` consistently with Identity and `PROFILE_URL` to the Profile API. The outbox worker additionally requires `BROKER_HTTP_URL`, `BROKER_USER` and `BROKER_PASSWORD`. The old Deliverable 3 commands below describe the transport shape but require authentication metadata on the current implementation.

The full suite runs against real PostgreSQL. Test databases must be pre-created, then migrated explicitly: `RAILS_ENV=test bin/rails db:migrate` followed by `RAILS_ENV=test bin/rails test`. The integrated test runner provides those settings without giving application roles database-creation privileges.

Regenerate Ruby protobuf bindings with `script/generate_proto.py` using Python grpcio-tools, or the existing Ruby compiler workflow below. Keep `../api-gateway/contracts/buddy_discovery.proto` identical to the source contract.

## Run locally

Docker and Docker Compose are the only host requirements.

```bash
docker compose build grpc
docker compose run --rm grpc bin/rails db:prepare
docker compose up grpc
```

The insecure development gRPC endpoint listens on `localhost:50051`.

With `grpcurl` installed, create a buddy request using the checked-in contract:

```bash
grpcurl -plaintext \
  -import-path proto \
  -proto buddy_discovery/v1/buddy_discovery.proto \
  -d '{
    "sender_id": "11111111-1111-4111-8111-111111111111",
    "recipient_id": "22222222-2222-4222-8222-222222222222"
  }' \
  localhost:50051 \
  buddy_discovery.v1.BuddyDiscoveryService/SendBuddyRequest
```

Copy the returned `id` to call `GetBuddyRequest`, `RespondToBuddyRequest`, or `CancelBuddyRequest`. Server reflection is not required because `grpcurl` receives the `.proto` file explicitly.

Stop the service without deleting its database volume:

```bash
docker compose down
```

## Test and quality checks

Prepare the test database once, then run the tests and style checker:

```bash
docker compose run --rm -e RAILS_ENV=test grpc bin/rails db:prepare
docker compose run --rm -e RAILS_ENV=test grpc bin/rails test
docker compose run --rm --no-deps grpc bin/rubocop
```

The suite includes model tests, service-operation tests, authorization and state-transition checks, and a real HTTP/2 gRPC transport test.

## Regenerate protobuf code

After changing the `.proto` contract, regenerate the Ruby files on an x86_64 host:

```bash
docker compose run --rm --no-deps grpc \
  bundle exec grpc_tools_ruby_protoc \
  -I proto \
  --ruby_out=lib \
  --grpc_out=lib \
  proto/buddy_discovery/v1/buddy_discovery.proto
```

The `grpc-tools` gem does not currently include a native Linux ARM compiler. On an Apple Silicon host, run generation in an amd64 Ruby container or regenerate through CI; the service runtime itself remains ARM-native.

## Repository boundary

This service owns its PostgreSQL schema. The API Gateway/BFF should translate browser REST requests into these gRPC calls. Other services receive buddy-request changes through versioned domain events rather than reading this database directly.
