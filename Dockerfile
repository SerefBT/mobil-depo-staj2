# Full-stack image: shared Flutter web + ASP.NET API. PostgreSQL stays external.
FROM ubuntu:24.04 AS web-build
ARG FLUTTER_VERSION=3.47.8
ARG FLUTTER_SHA256=baf7dcc5a3dbba60fe863bf493a6cf203195621f7786eaa5a1bba02cd0d87dd2
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils libglu1-mesa && rm -rf /var/lib/apt/lists/*
RUN curl --fail --location --retry 3 "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" -o /tmp/flutter.tar.xz \
    && echo "${FLUTTER_SHA256}  /tmp/flutter.tar.xz" | sha256sum -c - \
    && tar -xf /tmp/flutter.tar.xz -C /opt && rm /tmp/flutter.tar.xz \
    && useradd --create-home --uid 1000 builder && mkdir /src && chown -R builder:builder /opt/flutter /src
ENV PATH="/opt/flutter/bin:${PATH}"
USER builder
WORKDIR /src
COPY --chown=builder:builder mobile/pubspec.yaml mobile/pubspec.lock ./
RUN flutter config --no-analytics && flutter pub get
COPY --chown=builder:builder mobile/lib ./lib
COPY --chown=builder:builder mobile/web ./web
RUN flutter build web --release --no-wasm-dry-run

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS api-build
WORKDIR /src
COPY backend/Depo.Api/Depo.Api.csproj backend/Depo.Api/packages.lock.json ./
RUN dotnet restore Depo.Api.csproj --locked-mode
COPY backend/Depo.Api/ ./
RUN dotnet publish Depo.Api.csproj -c Release --no-restore -o /out -p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=api-build /out ./
COPY --from=web-build /src/build/web ./wwwroot
COPY deploy/render-entrypoint.sh ./render-entrypoint.sh
EXPOSE 8080
ENTRYPOINT ["/bin/sh", "/app/render-entrypoint.sh"]
