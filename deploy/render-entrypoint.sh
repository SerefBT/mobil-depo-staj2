#!/bin/sh
set -eu
: "${ConnectionStrings__Database:?Set the Neon .NET connection string in Render}"
: "${Jwt__Key:?Set a random JWT key of at least 48 bytes in Render}"
export ASPNETCORE_URLS="http://0.0.0.0:${PORT:-8080}"
exec dotnet /app/Depo.Api.dll
