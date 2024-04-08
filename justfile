# Serve the docs on the local network for testing.
serve-docs:
    cd docs && go run -v github.com/anacrolix/missinggo/v2/cmd/http-file-server@latest -addr=":$PORT"

# I think I needed this because otherwise you have to know the local network hostname to use from
# other applications during development for arbitrary receivers.
forward-docs:
    ngrok http --domain="$DOMAIN" "$PORT" --scheme http,https