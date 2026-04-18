#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
#  create-secrets.sh – Seed AWS Secrets Manager with WordPress credentials
#
#  Run this BEFORE bootstrap.sh so ECS task execution role can pull secrets.
#
#  Usage:
#    APP_NAME=veba REGION=us-west-1 ./scripts/create-secrets.sh
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

APP_NAME="${APP_NAME:-veba}"
REGION="${REGION:-us-west-1}"

create_or_update_secret() {
  local name="$1"
  local value="$2"

  if aws secretsmanager describe-secret --secret-id "$name" --region "$REGION" &>/dev/null; then
    echo "Updating: $name"
    aws secretsmanager put-secret-value \
      --secret-id "$name" \
      --secret-string "$value" \
      --region "$REGION"
  else
    echo "Creating: $name"
    aws secretsmanager create-secret \
      --name "$name" \
      --secret-string "$value" \
      --region "$REGION"
  fi
}

generate_salt() {
  # 64-char random string safe for WordPress salts
  LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*()-_=+[]{}|;:,.<>?' </dev/urandom | head -c 64
}

for ENV in dev staging production; do
  echo ""
  echo "── $ENV ─────────────────────────────────────────────────────────────"

  # Database password — replace with real value before going live
  create_or_update_secret "$APP_NAME/$ENV/db-password" "${ENV}-db-password-CHANGE-ME"

  # WordPress auth keys & salts — stored as a single JSON blob
  # Generates fresh random values; re-running this rotates them (logs out all users)
  SALTS_JSON=$(printf '{"auth_key":"%s","secure_auth_key":"%s","logged_in_key":"%s","nonce_key":"%s","auth_salt":"%s","secure_auth_salt":"%s","logged_in_salt":"%s","nonce_salt":"%s"}' \
    "$(generate_salt)" "$(generate_salt)" "$(generate_salt)" "$(generate_salt)" \
    "$(generate_salt)" "$(generate_salt)" "$(generate_salt)" "$(generate_salt)")

  create_or_update_secret "$APP_NAME/$ENV/wp-salts" "$SALTS_JSON"
done

echo ""
echo "Secrets created for all three environments."
echo "Next: set real DB passwords in AWS Console → Secrets Manager."
echo "  $APP_NAME/dev/db-password"
echo "  $APP_NAME/staging/db-password"
echo "  $APP_NAME/production/db-password"
