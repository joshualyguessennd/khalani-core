pragma solidity ^0.8.0;

import "../../src/Nexus/NexusGateway.sol";
import "../../src/diamondCommons/sharedFacets/DiamondCutFacet.sol";
import "../../src/Nexus/NexusGateway.sol";
import "../../src/Nexus/facets/AxonCrossChainRouter.sol";
import "../../src/Nexus/facets/bridges/AxonHandlerFacet.sol";
import "../../src/Nexus/facets/CrossChainRouter.sol";
import "../../src/Nexus/facets/bridges/MsgHandlerFacet.sol";
import "../../src/KaiToken.sol";
import "../../src/Vortex/Vortex.sol";
import "../../src/Nexus/facets/factory/TokenRegistry.sol";
import "../../src/Nexus/facets/bridges/AxonMultiBridgeFacet.sol";
import "forge-std/console.sol";
import {ConfigLib} from "./ConfigLib.sol";
import "../../src/PSM/KaiPSM.sol";


library DeployLib {

    function deployCoreContractsAxon() internal returns (ConfigLib.AxonNexusConfig memory out){
        //--------Nexus Diamond-------------//
        Nexus nexus = deployNexusDiamond();
        out.nexusDiamond = address (nexus);

        //--------Axon Facets-------------//
        bytes4[] memory axonCrossChainRouterfunctionSelectors;
        (out.axonCrossChainRouter, axonCrossChainRouterfunctionSelectors) = deployAxonCrossChainRouter();



        bytes4[] memory axonHandlerFunctionSelectors;
        (out.axonHandlerFacet, axonHandlerFunctionSelectors) = deployAxonHandlerFacet();

        bytes4[] memory axonMultiBridgeFacetfunctionSelectors;
        (out.axonMultiBridgeFacet, axonMultiBridgeFacetfunctionSelectors) = deployMultiBridgeFacet();


        //--------Token Registry-------------//
        bytes4[] memory tokenRegistryFunctionSelectors;
        (out.stableTokenRegistry, tokenRegistryFunctionSelectors) = deployTokenRegistry();

        //--------KaiToken-------------//
        out.kai = deployKai(out.nexusDiamond);


        //--------Vortex-------------//
        out.vortex = deployVortex(address(nexus), out.kai);


        //--------Making Facet cuts to diamond-------------//
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](4);
        cut[0] = IDiamond.FacetCut({
        facetAddress: out.axonCrossChainRouter,
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: axonCrossChainRouterfunctionSelectors
        });
        cut[1] = IDiamond.FacetCut({
        facetAddress: out.axonHandlerFacet,
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: axonHandlerFunctionSelectors
        });
        cut[2] = IDiamond.FacetCut({
        facetAddress: out.axonMultiBridgeFacet,
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: axonMultiBridgeFacetfunctionSelectors
        });
        cut[3] = IDiamond.FacetCut({
        facetAddress: out.stableTokenRegistry,
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: tokenRegistryFunctionSelectors
        });
        DiamondCutFacet(out.nexusDiamond).diamondCut(
            cut, //array of of cuts
            address(0), //initializer address
            "" //initializer data
        );
    }

    function deployCoreContracts() internal returns (ConfigLib.NexusConfig memory out){
        //--------Nexus Diamond-------------//
        Nexus nexus = deployNexusDiamond();
        out.nexusDiamond = address(nexus);

        //--------Deploy Kai-------//
        out.kai = deployKai(out.nexusDiamond);

        //--------Source Chain Facets-------------//
        address crossChainRouter;
        bytes4[] memory crossChainRouterfunctionSelectors;
        (crossChainRouter, crossChainRouterfunctionSelectors) = deployCrossChainRouter();
        out.crossChainRouter = crossChainRouter;

        address hyperlaneFacet;
        bytes4[] memory hyperlaneFacetfunctionSelector;
        (hyperlaneFacet, hyperlaneFacetfunctionSelector)  = deployHyperlaneFacet();
        out.hyperlaneFacet = hyperlaneFacet;

        address msgHandler;
        bytes4[] memory msgHandlerFunctionSelectors;
        (msgHandler, msgHandlerFunctionSelectors) = deployMsgHandlerFacet();
        out.msgHandlerFacet = msgHandler;

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](3);
        cut[0] = IDiamond.FacetCut({
        facetAddress: crossChainRouter,
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: crossChainRouterfunctionSelectors
        });
        cut[1] = IDiamond.FacetCut({
        facetAddress: hyperlaneFacet,
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: hyperlaneFacetfunctionSelector
        });
        cut[2] = IDiamond.FacetCut({
        facetAddress: msgHandler,
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: msgHandlerFunctionSelectors
        });
        DiamondCutFacet(address(nexus)).diamondCut(
            cut, //array of of cuts
            address(0), //initializer address
            "" //initializer data
        );
        //--------PSM-------------//
        out.psm = deployPSM(out.kai); //fix import issue
    }

    //--------Nexus Diamond-------------//
    function deployNexusDiamond() private returns (Nexus){
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        bytes4[] memory diamondCutFacetfunctionSelectors = new bytes4[](1);
        diamondCutFacetfunctionSelectors[0] = diamondCutFacet.diamondCut.selector;
        cut[0] = IDiamond.FacetCut({
        facetAddress: address(diamondCutFacet),
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: diamondCutFacetfunctionSelectors
        });
        DiamondArgs memory args;
        args.owner  = msg.sender;
        args.init = address(0);
        args.initCalldata = "";
        Nexus diamond = new Nexus(cut, args);
        return diamond;
    }

    //--------Axon Facets-------------//
    function deployAxonCrossChainRouter() private returns (address, bytes4[] memory axonCrossChainRouterfunctionSelectors) {
        AxonCrossChainRouter axonCrossChainRouter = new AxonCrossChainRouter();
        axonCrossChainRouterfunctionSelectors = new bytes4[](2);
        axonCrossChainRouterfunctionSelectors[0] = axonCrossChainRouter.withdrawTokenAndCall.selector;
        axonCrossChainRouterfunctionSelectors[1] = axonCrossChainRouter.withdrawMultiTokenAndCall.selector;
        return (address (axonCrossChainRouter),axonCrossChainRouterfunctionSelectors);
    }

    function deployAxonHandlerFacet() private returns (address, bytes4[] memory axonHandlerFunctionSelectors) {
        AxonHandlerFacet axonHandler = new AxonHandlerFacet(address(0x0));
        axonHandlerFunctionSelectors = new bytes4[](2);
        axonHandlerFunctionSelectors[0] = axonHandler.addValidNexusForChain.selector;
        axonHandlerFunctionSelectors[1] = axonHandler.handle.selector;
        return (address(axonHandler), axonHandlerFunctionSelectors);
    }

    function deployMultiBridgeFacet() private returns (address, bytes4[] memory multiBridgeFacetfunctionSelectors) {
        AxonMultiBridgeFacet multiBridgeFacet = new AxonMultiBridgeFacet(address(0x0));
        multiBridgeFacetfunctionSelectors = new bytes4[](4);
        multiBridgeFacetfunctionSelectors[0] = multiBridgeFacet.initMultiBridgeFacet.selector;
        multiBridgeFacetfunctionSelectors[1] = multiBridgeFacet.addChainInbox.selector;
        multiBridgeFacetfunctionSelectors[2] = multiBridgeFacet.bridgeTokenAndCallbackViaHyperlane.selector;
        multiBridgeFacetfunctionSelectors[3] = multiBridgeFacet.bridgeMultiTokenAndCallbackViaHyperlane.selector;
        return (address(multiBridgeFacet), multiBridgeFacetfunctionSelectors);
    }

    function deployTokenRegistry() private returns (address, bytes4[] memory tokenRegistryfunctionSelectors) {
        StableTokenRegistry tokenRegistry = new StableTokenRegistry();
        tokenRegistryfunctionSelectors = new bytes4[](3);
        tokenRegistryfunctionSelectors[0] = tokenRegistry.initTokenFactory.selector;
        tokenRegistryfunctionSelectors[1] = tokenRegistry.registerMirrorToken.selector;
        tokenRegistryfunctionSelectors[2] = tokenRegistry.registerKai.selector;
        return (address(tokenRegistry), tokenRegistryfunctionSelectors);
    }

    //--------Source Chain Facets-------------//
    function deployCrossChainRouter() private returns (address, bytes4[] memory ccrFunctionSelectors) {
        CrossChainRouter ccr = new CrossChainRouter();
        ccrFunctionSelectors = new bytes4[](4);
        ccrFunctionSelectors[0] = ccr.initializeNexus.selector;
        ccrFunctionSelectors[1] = ccr.depositTokenAndCall.selector;
        ccrFunctionSelectors[2] = ccr.depositMultiTokenAndCall.selector;
        ccrFunctionSelectors[3] = ccr.setKai.selector;
        return (address(ccr), ccrFunctionSelectors);
    }

    function deployHyperlaneFacet() private returns (address, bytes4[] memory hyperlaneFacetfunctionSelectors) {
        HyperlaneFacet hyperlaneFacet = new HyperlaneFacet();
        hyperlaneFacetfunctionSelectors = new bytes4[](4);
        hyperlaneFacetfunctionSelectors[0] = hyperlaneFacet.initHyperlaneFacet.selector;
        hyperlaneFacetfunctionSelectors[1] = hyperlaneFacet.bridgeTokenAndCall.selector;
        hyperlaneFacetfunctionSelectors[2] = hyperlaneFacet.bridgeMultiTokenAndCall.selector;
        hyperlaneFacetfunctionSelectors[3] = hyperlaneFacet.interchainSecurityModule.selector;
        return (address(hyperlaneFacet), hyperlaneFacetfunctionSelectors);
    }

    function deployMsgHandlerFacet() private returns (address, bytes4[] memory msgHandlerFacetfunctionSelectors) {
        MsgHandlerFacet msgHandlerFacet = new MsgHandlerFacet(address(0x0));
        msgHandlerFacetfunctionSelectors = new bytes4[](2);
        msgHandlerFacetfunctionSelectors[0] = msgHandlerFacet.addChainTokenForMirrorToken.selector;
        msgHandlerFacetfunctionSelectors[1] = msgHandlerFacet.handle.selector;
        return (address(msgHandlerFacet), msgHandlerFacetfunctionSelectors);
    }

    //--Vortex--//
    function deployVortex(address _axonNexus, address _kai) private returns (address){
        Vortex vortex = new Vortex(_axonNexus,_kai);
        console.log("Vortex deployed at - ", address(vortex));
        return address(vortex);
    }

    //--------Tokens-------------//
    // minter burner is both nexus and psm
    // minter burner is both nexus and psm
    function deployKai(address minterBurner) private returns (address) {
        Kai kai = new Kai();
        kai.initialize("KAI","KAI");
        kai.transferMinterBurnerRole(minterBurner);
        return address(kai);
    }

    function deployMirrorToken(address sourceAddress, string memory _name, string memory _symbol, uint8 _decimals, uint _chainId, address axonNexus) internal returns (address) {
        USDMirror mirrorToken = new USDMirror();
        mirrorToken.initialize(_name, _symbol, _decimals, _chainId);
        mirrorToken.transferMinterBurnerRole(axonNexus);
        console.log("Registering to registry");
        StableTokenRegistry(axonNexus).registerMirrorToken(_chainId,sourceAddress,address(mirrorToken));
        console.log("Deployed mirror token %s %s to %s", _name, _symbol, address(mirrorToken));
        return address(mirrorToken);
    }

    function initializeAxonNexus(ConfigLib.DeployConfig memory config, ConfigLib.AxonNexusConfig memory axonConfig) internal{
        AxonMultiBridgeFacet(axonConfig.nexusDiamond).initMultiBridgeFacet(config.hyperlaneMailbox,config.hyperlaneMailbox,0);
        StableTokenRegistry(axonConfig.nexusDiamond).initTokenFactory(axonConfig.kai);
    }

    function initializeRemoteNexus(
        ConfigLib.DeployConfig memory config,
        ConfigLib.NexusConfig memory nexusConfig,
        address axon,
        uint chainIdAxon
    ) internal{
        CrossChainRouter(nexusConfig.nexusDiamond).initializeNexus(nexusConfig.kai,axon,chainIdAxon);
        HyperlaneFacet(nexusConfig.nexusDiamond).initHyperlaneFacet(config.hyperlaneMailbox,config.hyperlaneISM);
    }

    //--PSM--//
    function deployPSM(address _kai) private returns (address) {
        KaiPSM psm = new KaiPSM();
        psm.initialize(_kai);
        //transfer minter burner role to psm
        Kai(_kai).transferMinterBurnerRole(address(psm));
        console.log("PSM deployed at - ", address(psm));
        return address(psm);
    }
}