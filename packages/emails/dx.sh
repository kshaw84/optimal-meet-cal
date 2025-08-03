#!/bin/bash

# Load RESEND_API_KEY from .env file if it exists
if [ -f "../../.env" ]; then
    RESEND_API_KEY_FROM_ENV=$(grep "^[[:space:]]*RESEND_API_KEY=" "../../.env" | sed 's/^[[:space:]]*RESEND_API_KEY=//')
    if [ -n "$RESEND_API_KEY_FROM_ENV" ]; then
        export RESEND_API_KEY="$RESEND_API_KEY_FROM_ENV"
    fi
fi

# Check if RESEND_API_KEY is set
if [ -z "$RESEND_API_KEY" ]; then
    echo "Starting mailhog for email testing..."
    # Try docker compose first, fallback to docker-compose
    if command -v docker compose &> /dev/null; then
        docker compose up -d
    elif command -v docker-compose &> /dev/null; then
        docker-compose up -d
    else
        echo "Error: Neither 'docker compose' nor 'docker-compose' is available"
        exit 1
    fi
    echo "Mailhog started successfully"
else
    echo "✅ Using Resend for email delivery (RESEND_API_KEY is set)"
    echo "   - Local development emails will be sent via Resend"
    echo "   - No Mailhog container needed"
fi 