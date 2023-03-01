## Nexus Deployment + Checklists (Hyperlane Specific)

### Deployment checklist on Khala Network
1. Deploy `Nexus` contract - Diamond proxy for all the facets
2. Deploy `PAN` token on Khala Network
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
      3. `registerPan`
4. Deploy `Vortex` contract

#### Initialize checklist on Khala Network
- AxonMultiBridgeFacet(axonNexus).initMultiBridgeFacet(MOCK_ADDR_CELER_BUS, address(mailboxAxon), 3);
- AxonMultiBridgeFacet(axonNexus).addChainInbox(5,ethNexus);
- AxonHandlerFacet(axonNexus).addValidNexusForChain(5,TypeCasts.addressToBytes32(address(ethNexus)));
- StableTokenRegistry(axonNexus).initTokenFactory(panOnAxon);
- StableTokenRegistry(axonNexus).registerPan(5,panOnEth);
- StableTokenRegistry(axonNexus).registerPan(43113,panOnAvax);
- StableTokenRegistry(axonNexus).registerMirrorToken(5, usdcE, usdcEth);


### Deployment checklist on other chains
1. Deploy `PAN` token
2. Deploy `PanPSM`contract and initialize it with `PAN` token
3. Deploy `Nexus` contract - Diamond proxy for all the facets
4. Deploy `Diamond Facets` in the following order
   1. CrossChainRouter
      1. `initializeNexus`
      2. `depositTokenAndCall`
      3. `depositMultiTokenAndCall`
      4. `setPan`
   2. HyperlaneFacet
      1. `initHyperlaneFacet`
      2. `bridgeTokenAndCall`
      3. `bridgeMultiTokenAndCall`
      4. `sendMultiCall`
   3. MsgHandlerFacet
      1. `addChainTokenForMirrorToken`
      2. `handle`
      
#### Initialize checklist on other chains
- CrossChainRouter(ethNexus).initializeNexus(panOnEth,axonNexus,10012);
- HyperlaneFacet(ethNexus).initHyperlaneFacet(address(mailboxEth),MOCK_ISM);

