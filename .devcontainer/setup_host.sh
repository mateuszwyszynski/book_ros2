#!/usr/bin/env bash

if [ ! -f ".env" ]; then
    echo "INCORRECT SETUP: .env file does not exist. Create it based on .env.template."
    exit 1
fi

# Ensure that what we are mounting exists
mkdir -p ${HOME}/.claude

USER_ID=$(id -u)
GROUP_ID=$(id -g)

HOST_CLAUDE_DIR="$HOME/.claude"
export USER_ID GROUP_ID HOST_CLAUDE_DIR
envsubst < .devcontainer/docker-compose.template.yml > .devcontainer/docker-compose.yml
