#!/bin/bash
#
mkdir -p "${PWD}/.vscode.data/Backups"
docker run --rm -p 127.0.0.1:8443:8443 \
  --name ide \
  -v "${PWD}:/root/project" \
  -v "${PWD}/.vscode.data:/root/.local/share/code-server" \
  -v "${PWD}/.vscode.logs:/root/.cache/code-server/logs" \
  ide code-server --allow-http --no-auth
