# Claude Code with ACP

Adds `@agentclientprotocol/claude-agent-acp` to the standard Claude Code docker sbx sandbox.

Documentation for sandbox templates: https://docs.docker.com/ai/sandboxes/customize/templates/

## Building

Run:

```bash
docker build -t alexdaiii/claude-acp-sbx:latest --push .
```

Docker sbx requires you to push iot to a registry first - or export it to a .tar file.
Registries that are not DockerHub only work without authentication (as of the documentation on 2026-05-12). 

Alternatively, you might be able to just modify the bottom shell script to just first install `@agentclientprotocol/claude-agent-acp` into
the microVM on creation so you always have the latest version.

## Usage

For regular terminal usage:

```bash
sbx run --template alexdaiii/claude-acp-sbx:latest claude
```

If following the instructions in this blog: https://olegselajev.substack.com/p/safe-coding-agents-in-intellij-idea,
you will need to modify the script for starting the OpenCode sandbox.

I reccomend writing this script in the project file instead of the `~` home dir
since, you might need project specific volumes mounted to the microVM.

```shell
#!/bin/bash
SANDBOX="claude-$(basename "$PWD")"

# Redirect ALL stderr to log — nothing should reach ZED except ACP JSON on stdout
exec 2>>/tmp/claude-sandbox.log

# Try to create sandbox; if it already exists, verify exec works
# NOTE: If you need to add any volumes, add it here
if ! sbx create --name "$SANDBOX" claude "$PWD" >>/tmp/claude-sandbox.log; then
    # Sandbox already exists — check if container is actually running
    if ! sbx exec "$SANDBOX" true >>/tmp/claude-sandbox.log; then
        echo "Sandbox stale, recreating..." >>/tmp/claude-sandbox.log
        sbx rm "$SANDBOX" >>/tmp/claude-sandbox.log || true
        sbx create --name "$SANDBOX" --template alexdaiii/claude-acp-sbx:latest "$PWD" >>/tmp/claude-sandbox.log
    fi
fi

# Run Claude Code in ACP mode over stdio
echo "$(date): starting claude code acp in sandbox $SANDBOX" >>/tmp/claude-sandbox.log
exec sbx exec -i "$SANDBOX" claude-agent-acp
```