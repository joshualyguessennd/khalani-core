export REMOTE=sepolia
export POOL_DEPLOYER=0x73B31aC967f46dB2C45280C7f5d1D3ee7F38E122
export KAI_AXON=0x7Da15dD2916705862f5e5e02964f4910A6E7cB75
export AMOUNT=150000

# Extract tokens and mirror tokens for the given remote
tokens=$(jq -r --arg remote "$REMOTE" '.[$remote].tokens | join(",")' config/tokens.json)
mirror_tokens=$(jq -r --arg remote "$REMOTE" '.[$remote].mirrorTokens | join(",")' config/tokens.json)

# Export environment variables
export TOKENS="$tokens"
export MIRROR_TOKENS="$mirror_tokens"

forge script script/BridgeToken.s.sol --broadcast --aws true -vv