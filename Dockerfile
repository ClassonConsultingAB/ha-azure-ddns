FROM mcr.microsoft.com/dotnet/sdk:10.0-alpine AS build
ARG GITHUB_SOURCE_URL=https://nuget.pkg.github.com/ClassonConsultingAB/index.json
WORKDIR /src
RUN --mount=type=secret,id=github_token \
    dotnet nuget add source \
        --username docker \
        --password "$(cat /run/secrets/github_token)" \
        --store-password-in-clear-text \
        --name github ${GITHUB_SOURCE_URL}
COPY ./src/Host/*.csproj ./src/Host/
COPY ./src/Core/*.csproj ./src/Core/
COPY ./src/Integration/*.csproj ./src/Integration/
RUN dotnet restore ./src/Host/AzureDdns.Host.csproj
COPY ./src ./src
RUN dotnet publish ./src/Host/AzureDdns.Host.csproj -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/runtime:10.0-alpine AS final
WORKDIR /app
RUN apk update --no-cache
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "AzureDdns.Host.dll"]
