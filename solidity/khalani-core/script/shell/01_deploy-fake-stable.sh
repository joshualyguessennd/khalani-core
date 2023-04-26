#!/bin/bash

set -e

if [[ -z "${PRIVATE_KEY}" ]]; then
  echo "Error: PRIVATE_KEY environment variable is not set, use [export PRIVATE_KEY = <private key>] to set it."
  exit 1
fi
export REMOTE=fuji
export TOKENS=USDC,USDT,BUSD
export DECIMALS=6,6,18
CHAIN_ID=$(jq --arg remote "$REMOTE" '.[$remote].chainId' config/deploy_config.json)

echo "Starting forge script..."

# deploy tokens to the CHAIN_ID
forge script script/DeployFakeStable.s.sol --legacy --broadcast --private-key "${PRIVATE_KEY}"

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
