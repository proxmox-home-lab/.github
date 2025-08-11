export VAULT_ADDR="https://vault.sergioaten.cloud"

if [ -z "$VAULT_CLIENT_ID" ] || [ -z "$VAULT_SECRET_ID" ]; then
  echo "VAULT_CLIENT_ID and VAULT_SECRET_ID must be set"
  exit 1
fi

AUTH_DATA=$(vault write -format=json auth/approle/login role_id=$VAULT_CLIENT_ID secret_id=$VAULT_SECRET_ID | jq)
echo $AUTH_DATA
export VAULT_TOKEN=$(echo $AUTH_DATA | jq -r .auth.client_token)
echo $VAULT_TOKEN
DB_DATA=$(vault kv get -format=json -mount="kv" "proxmox-home-lab/terraform-backend" | jq)

for key in $(echo $DB_DATA | jq -r '.data.data | keys[]'); do
  value=$(echo $DB_DATA | jq -r ".data.data.$key")
  export $key="$value"
done
