#!/bin/bash

set -e

if [[ -z "${AWS_KMS_KEY_ID}" ]]; then
  echo "Error: AWS_KMS_KEY_ID environment variable is not set, use [export AWS_KMS_KEY_ID=<private key>] to set it."
  exit 1
fi
export REMOTE=optimismgoerli
export TOKENS=USDC,USDT
export DECIMALS=6,6
export FAUCET=0x6542C57F3D8618f571889FA04a36c469F87383A7
export FAUCET_AMOUNT=1000000000
CHAIN_ID=$(jq --arg remote "$REMOTE" '.[$remote].chainId' config/deploy_config.json)

echo "Starting forge script..."

# deploy tokens to the CHAIN_ID
forge script script/DeployFakeStable.s.sol --broadcast --verify --aws true --sender 0x04b0bff8776d8cc0ef00489940afd9654c67e4c7

echo "Forge script completed. Processing JSON..."

chain_id=${CHAIN_ID}
input_file="broadcast/DeployFakeStable.s.sol/${chain_id}/run-latest.json"
output_file="config/test_stables.json"

contract_data=$(jq --arg chain_id "$chain_id" '{($chain_id): [.transactions[] | select(.transactionType == "CREATE") | {name: .arguments[0], symbol: .arguments[1], decimal: .arguments[2] | tonumber, address: .contractAddress}]}' $input_file)

echo "JSON processing completed. Checking output file existence..."

# Check if the output file exists
if [ -f "$output_file" ]; then
  echo "Output file exists."

  # Check if the chain_id exists in the output file
  if jq --exit-status --arg chain_id "$chain_id" 'map(keys[] == $chain_id) | any' "$output_file" > /dev/null; then
    echo "Chain ID exists. Updating values..."
    # If the chain_id exists, update the values for that chain_id
    updated_data=$(jq --argjson new_data "$contract_data" --arg chain_id "$chain_id" 'map(if .[$chain_id] then .[$chain_id] = ($new_data | .[$chain_id]) else . end)' "$output_file")
  else
    echo "Chain ID does not exist. Appending values..."
    # If the chain_id does not exist, append the new data
    updated_data=$(jq --arg chain_id "$chain_id" --argjson contract_data "$contract_data" '. + [{($chain_id): $contract_data[$chain_id]}]' "$output_file")
  fi

  echo "$updated_data" | jq . > "$output_file"
  echo "Updating file completed."
else
  echo "Output file does not exist. Creating file..."
  # If the output file does not exist, create it with the new data wrapped in an array
  jq -n --arg chain_id "$chain_id" --argjson contract_data "$contract_data" "[{(\$chain_id): \$contract_data[\$chain_id]}]" > "$output_file"
fi

echo "Script completed."
