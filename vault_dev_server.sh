#!/bin/sh

vault server --dev &
sleep 2

export VAULT_TOKEN=`cat ~/.vault-token`
export VAULT_ADDR='http://127.0.0.1:8200'

echo "Set vault root token to $VAULT_TOKEN"
# enable approle authentication

vault auth-enable approle
vault mount transit

vault policy-write test-policy ./test/test-policy.hcl

# set default policies for "testrole"
curl -X POST -H "X-Vault-Token:$VAULT_TOKEN" -d '{"policies":"default,dev-policy,test-policy"}' http://127.0.0.1:8200/v1/auth/approle/role/testrole
#curl -X POST -H "X-Vault-Token:$VAULT_TOKEN" http://127.0.0.1:8200/v1/transit/keys/foo
# pull the new secrets out of the vault
VAULT_ROLE_ID=`curl -X GET -H "X-Vault-Token:$VAULT_TOKEN" http://127.0.0.1:8200/v1/auth/approle/role/testrole/role-id | jq -r .data.role_id`
VAULT_SECRET_ID=`curl -X POST -H "X-Vault-Token:$VAULT_TOKEN" http://127.0.0.1:8200/v1/auth/approle/role/testrole/secret-id | jq -r .data.secret_id`

echo ${VAULT_ROLE_ID} > .role_id
echo ${VAULT_SECRET_ID} > .secret_id

echo ""
echo "******************"
echo "Vault is running in the background to kill it run:"
echo "  pkill vault"
echo "******************"
echo ""
