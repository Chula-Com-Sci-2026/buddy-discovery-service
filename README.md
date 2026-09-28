# Buddy Discovery Service

Buddy Discovery Service is a gRPC microservice for the **Can't Run Alone** platform. It owns runner discovery, buddy requests, buddy relationships, blocking, and the candidate projection used for searching. This repository currently implements the first Deliverable 3 vertical slice: the complete lifecycle of a buddy request.

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

Runner search, buddy lists, blocking, PostGIS candidate projections, Kafka events, expiration jobs, and JWT authorization are planned but not implemented yet.

## Technology

- Ruby 3.4.6
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
