# Buddy Discovery Service Bruno collection

Open the repository root as a collection in Bruno and select the `local`
environment. Start the gRPC service on port 50051, then send requests `01`
through `07` in order from the desktop app.

Requests `01` and `05` save their returned IDs as `requestId` and
`cancelRequestId`. Request `07` is intentionally expected to return `NOT_FOUND`.
Use fresh sender/recipient UUIDs, or reset the development database, when
repeating the demo because duplicate pending requests are rejected.

The collection loads `proto/buddy_discovery/v1/buddy_discovery.proto` directly,
so the Bruno contract stays aligned with the service contract.
