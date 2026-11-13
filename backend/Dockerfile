FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY Depo.Api/Depo.Api.csproj Depo.Api/
RUN dotnet restore Depo.Api/Depo.Api.csproj
COPY Depo.Api/ Depo.Api/
RUN dotnet publish Depo.Api -c Release -o /out --no-restore
FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /out .
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "Depo.Api.dll"]
