FROM golang:1.25-bookworm AS build
WORKDIR /src
COPY server/go.mod server/go.sum ./
RUN go mod download
COPY server/*.go ./
COPY server/migrations ./migrations
RUN CGO_ENABLED=0 go build -trimpath -o /netbot .

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=build /netbot /usr/local/bin/netbot
COPY data/lan/inspection.json /opt/netbot/inspection.json
ENV MAP_FILE=/opt/netbot/inspection.json
USER 65534:65534
ENTRYPOINT ["/usr/local/bin/netbot"]
