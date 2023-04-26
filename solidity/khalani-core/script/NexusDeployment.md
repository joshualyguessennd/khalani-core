## Nexus Deployment

### Steps
#### Generate a new private key to be the deployer and fund it on all chains.

The same wallet is used for deploying to all the chains: Khalani and end-chains (Goerli, Fuji).
> TODO: We probably need to have different ones and use multi-sig (Safe) for the management.

```
cast wallet new
> Address: 0x3941e6a9F2D619A3BEA4aE3741353Cefc795346f = DEPLOYER_PUBLIC_KEY
> Private Key: 0xe47f03d74bb10c79f6f08302e2d5f65688155619c47be69b966407aad8dc1a8c = DEPLOYER_PRIVATE_KEY

<top up the balance of DEPLOYER_PUBLIC_KEY on all the chains>
```

#### Run [deploy-nexus-multichain.sh](shell/02_deploy-nexus-multichain.sh) from the `khalani-core` working directory

Configure [deploy_config.json](..%2Fconfig%2Fdeploy_config.json):
- set the RPC URL of the `khalanitestnet` and the end-chains
- set the contract addresses on the `khalanitestnet`. The other chains should be up-to-date.
- leave tokens be an empty array. This is used as part of another script [deploy-mirror-tokens.sh](shell/03_deploy-mirror-tokens.sh).


```
cd <root>
cd solidity/khalani-core
./script/deploy-nexus-multichain.sh
```

#### Run [deploy-mirror-tokens.sh](shell/03_deploy-mirror-tokens.sh) for each remote chain
Configure [deploy_config.json](..%2Fconfig%2Fdeploy_config.json): set `tokens` to be mirrored on each end-chain (not Khalani)

For each end-chain, change `REMOTE` in [deploy-mirror-tokens.sh](shell/03_deploy-mirror-tokens.sh) and run:
```
./script/deploy-mirror-tokens.sh
```

### Deployment checklist on Khala Network
1. Deploy `Nexus` contract - Diamond proxy for all the facets
2. Deploy `KAI` token on Khala Network
3. Deploy `Diamond Facets` in the following order
   1. AxonCrossChainRouter
      1. `withdrawTokenAndCall`
      2. `withdrawMultiTokenAndCall`
   2. AxonHandler
      1. `addValidNexusForChain`
      2. `handle`
   3. AxonMultiBridgeFacet
      1. `initMultiBridgeFacet` 
      2. `addChainInbox`
      3. `bridgeTokenAndCallbackViaHyperlane`
      4. `bridgeMultiTokenAndCallbackViaHyperlane`
   4. StableTokenRegistry
      1. `initTokenFactory`
      2. `registerMirrorToken`
      3. `registerKai`
4. Deploy `Vortex` contract

#### Initialize checklist on Khala Network
- AxonMultiBridgeFacet(axonNexus).initMultiBridgeFacet(MOCK_ADDR_CELER_BUS, address(mailboxAxon), 3);
- AxonMultiBridgeFacet(axonNexus).addChainInbox(5,ethNexus);
- AxonHandlerFacet(axonNexus).addValidNexusForChain(5,TypeCasts.addressToBytes32(address(ethNexus)));
- StableTokenRegistry(axonNexus).initTokenFactory(kaiOnAxon);
- StableTokenRegistry(axonNexus).registerKai(5,kaiOnEth);
- StableTokenRegistry(axonNexus).registerKai(43113,kaiOnAvax);
- StableTokenRegistry(axonNexus).registerMirrorToken(5, usdcE, usdcEth);


### Deployment checklist on other chains
1. Deploy `KAI` token
2. Deploy `KaiPSM`contract and initialize it with `KAI` token
3. Deploy `Nexus` contract - Diamond proxy for all the facets
4. Deploy `Diamond Facets` in the following order
   1. CrossChainRouter
      1. `initializeNexus`
      2. `depositTokenAndCall`
      3. `depositMultiTokenAndCall`
      4. `setKai`
   2. HyperlaneFacet
      1. `initHyperlaneFacet`
      2. `bridgeTokenAndCall`
      3. `bridgeMultiTokenAndCall`
      4. `sendMultiCall`
   3. MsgHandlerFacet
      1. `addChainTokenForMirrorToken`
      2. `handle`
      
#### Initialize checklist on other chains
- CrossChainRouter(ethNexus).initializeNexus(kaiOnEth,axonNexus,10012);
- HyperlaneFacet(ethNexus).initHyperlaneFacet(address(mailboxEth),MOCK_ISM);

