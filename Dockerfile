FROM rust:1.69.0-buster as builder
WORKDIR /qdrant

# based on https://github.com/docker/buildx/issues/510
ARG TARGETARCH
ENV TARGETARCH=${TARGETARCH:-amd64}

WORKDIR /qdrant

RUN cargo install --git https://github.com/gokayokyay/depcache.git --rev 96fc8d3816aa3a53004743693103cfcc5ae460a9

COPY ./tools/target_arch.sh ./target_arch.sh
RUN echo "Building for $TARGETARCH, arch: $(bash target_arch.sh)"

RUN apt-get update \
    && ( apt-get install -y gcc-multilib || echo "Warning: not installing gcc-multilib" ) \
    && apt-get install -y clang cmake gcc-aarch64-linux-gnu g++-aarch64-linux-gnu protobuf-compiler \
    && rustup component add rustfmt


RUN rustup target add $(bash target_arch.sh)

COPY . .

RUN --mount=type=secret,id=BUCKET_NAME \
  --mount=type=secret,id=ACCESS_KEY \
  --mount=type=secret,id=SECRET_KEY \
  --mount=type=secret,id=ENDPOINT \
  --mount=type=secret,id=REGION \
  BUCKET_NAME=$(cat /run/secrets/BUCKET_NAME) \
  ACCESS_KEY=$(cat /run/secrets/ACCESS_KEY) \
  SECRET_KEY=$(cat /run/secrets/SECRET_KEY) \
  ENDPOINT=$(cat /run/secrets/ENDPOINT) \
  REGION=$(cat /run/secrets/REGION) depcache --target=$(bash target_arch.sh) --profile=release

RUN cargo build --release --target $(bash target_arch.sh) --bin qdrant
RUN --mount=type=secret,id=BUCKET_NAME \
  --mount=type=secret,id=ACCESS_KEY \
  --mount=type=secret,id=SECRET_KEY \
  --mount=type=secret,id=ENDPOINT \
  --mount=type=secret,id=REGION \
  BUCKET_NAME=$(cat /run/secrets/BUCKET_NAME) \
  ACCESS_KEY=$(cat /run/secrets/ACCESS_KEY) \
  SECRET_KEY=$(cat /run/secrets/SECRET_KEY) \
  ENDPOINT=$(cat /run/secrets/ENDPOINT) \
  REGION=$(cat /run/secrets/REGION) depcache --target=$(bash target_arch.sh) --profile=release

RUN mv target/$(bash target_arch.sh)/release/qdrant /qdrant/qdrant

FROM debian:11-slim
ARG APP=/qdrant

RUN apt-get update \
    && apt-get install -y ca-certificates tzdata \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 6333
EXPOSE 6334

ENV TZ=Etc/UTC \
    RUN_MODE=production

RUN mkdir -p ${APP}

COPY --from=builder /qdrant/qdrant ${APP}/qdrant
COPY --from=builder /qdrant/config ${APP}/config

WORKDIR ${APP}

CMD ["./qdrant"]
