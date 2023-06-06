#!/bin/bash

if [[ -z "${PRIVATE_KEY}" ]]; then
  echo "Error: PRIVATE_KEY environment variable is not set."
  exit 1
fi

export AXON=khalanitestnet
export REMOTES=sepolia,fuji,mumbai,bsctestnet,arb-goerli,optimism-goerli,godwoken-testnet

#### ------------ONLY FOR V0 TEST TOKEN PURPOSE---------- ####
# Set the input and output file paths
input_file="config/test_stables.json"
output_file="config/deploy_config.json"

# Extract the chain IDs from test_stables.json
chain_ids=$(jq 'map(keys[])' $input_file)

# Loop through the chain IDs
for chain_id in $(echo "$chain_ids" | jq -r '.[]'); do
  # Get the addresses for the corresponding chain ID
  addresses=$(jq --arg chain_id "$chain_id" '.[] | select(.[$chain_id]) | .[$chain_id] | map(.address)' $input_file)

  # Update the tokens array for the corresponding chain ID in deploy_config.json
  updated_config=$(jq --arg chain_id "$chain_id" --argjson addresses "$addresses" '(.[] | select(.chainId == ($chain_id | tonumber)) | .tokens) |= $addresses' $output_file)

  # Save the updated config to the deploy_config.json file
  echo "$updated_config" | jq . > $output_file
done


# Format the output JSON file with two-space indentation
temp_file=$(mktemp)
jq '.' "$output_file" > "$temp_file" && mv "$temp_file" "$output_file"
#######-----------END-----------########

echo "Starting forge script..."
forge script script/DeployNexusMultiChain.s.sol --legacy --broadcast --private-key $PRIVATE_KEY -vvv
echo "forge script completed."