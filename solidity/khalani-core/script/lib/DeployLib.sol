pragma solidity ^0.8.0;

import "../../src/Nexus/NexusGateway.sol";
import "../../src/diamondCommons/sharedFacets/DiamondCutFacet.sol";
import "../../src/Nexus/NexusGateway.sol";
import "../../src/Nexus/facets/AxonCrossChainRouter.sol";
import "../../src/Nexus/facets/bridges/AxonHandlerFacet.sol";
import "../../src/Nexus/facets/CrossChainRouter.sol";
import "../../src/Nexus/facets/bridges/MsgHandlerFacet.sol";
import "../../src/PanToken.sol";
import "../../src/Vortex/Vortex.sol";
import "../../src/Nexus/facets/factory/TokenRegistry.sol";
import "../../src/Nexus/facets/bridges/AxonMultiBridgeFacet.sol";
import "forge-std/console.sol";
import {ConfigLib} from "./ConfigLib.sol";
import "../../src/PSM/PanPSM.sol";


library DeployLib {

    function deployCoreContractsAxon() internal returns (ConfigLib.AxonNexusConfig memory out){
        //--------Nexus Diamond-------------//
        Nexus nexus = deployNexusDiamond();
        out.nexusDiamond = address (nexus);

        //--------Axon Facets-------------//
        address axonCrossChainRouter;
        bytes4[] memory axonCrossChainRouterfunctionSelectors;
        (axonCrossChainRouter, axonCrossChainRouterfunctionSelectors) = deployAxonCrossChainRouter();
        out.axonCrossChainRouter = axonCrossChainRouter;

        address axonHandler;
        bytes4[] memory axonHandlerFunctionSelectors;
        (axonHandler, axonHandlerFunctionSelectors) = deployAxonHandlerFacet();
        out.axonHandlerFacet = axonHandler;

        address axonMultiBridgeFacet;
        bytes4[] memory axonMultiBridgeFacetfunctionSelectors;
        (axonMultiBridgeFacet, axonMultiBridgeFacetfunctionSelectors) = deployMultiBridgeFacet();
        out.axonMultiBridgeFacet = axonMultiBridgeFacet;

        //--------Token Registry-------------//
        (address tokenRegistry, bytes4[] memory tokenRegistryFunctionSelectors) = deployTokenRegistry();
        out.stableTokenRegistry = tokenRegistry;
        //--------PanToken-------------//
        address panOnAxon = deployPan(out.nexusDiamond);
        out.pan = panOnAxon;

        //--------Vortex-------------//
        address vortex = deployVortex(address(nexus), panOnAxon);
        out.vortex = vortex;

        //--------Making Facet cuts to diamond-------------//
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](4);
        cut[0] = IDiamond.FacetCut({
        facetAddress: axonCrossChainRouter,
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: axonCrossChainRouterfunctionSelectors
        });
        cut[1] = IDiamond.FacetCut({
        facetAddress: axonHandler,
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: axonHandlerFunctionSelectors
        });
        cut[2] = IDiamond.FacetCut({
        facetAddress: axonMultiBridgeFacet,
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: axonMultiBridgeFacetfunctionSelectors
        });
        cut[3] = IDiamond.FacetCut({
        facetAddress: tokenRegistry,
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: tokenRegistryFunctionSelectors
        });
        DiamondCutFacet(address(nexus)).diamondCut(
            cut, //array of of cuts
            address(0), //initializer address
            "" //initializer data
        );
    }

    function deployCoreContracts() internal returns (ConfigLib.NexusConfig memory out){
        //--------Nexus Diamond-------------//
        Nexus nexus = deployNexusDiamond();
        out.nexusDiamond = address(nexus);

        //--------Deploy Pan-------//
        address pan = deployPan(out.nexusDiamond);

        //--------Source Chain Facets-------------//
        address crossChainRouter;
        bytes4[] memory crossChainRouterfunctionSelectors;
        (crossChainRouter, crossChainRouterfunctionSelectors) = deployCrossChainRouter();
        out.crossChainRouter = crossChainRouter;

        address hyperlaneFacet;
        bytes4[] memory hyperlaneFacetfunctionSelector;
        (hyperlaneFacet, hyperlaneFacetfunctionSelector)  = deployHyperlaneFacet();

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
        address psm = deployPSM(pan); //fix import issue
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
        tokenRegistryfunctionSelectors[2] = tokenRegistry.registerPan.selector;
        return (address(tokenRegistry), tokenRegistryfunctionSelectors);
    }

    //--------Source Chain Facets-------------//
    function deployCrossChainRouter() private returns (address, bytes4[] memory ccrFunctionSelectors) {
        CrossChainRouter ccr = new CrossChainRouter();
        ccrFunctionSelectors = new bytes4[](4);
        ccrFunctionSelectors[0] = ccr.initializeNexus.selector;
        ccrFunctionSelectors[1] = ccr.depositTokenAndCall.selector;
        ccrFunctionSelectors[2] = ccr.depositMultiTokenAndCall.selector;
        ccrFunctionSelectors[3] = ccr.setPan.selector;
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
    function deployPan(address minterBurner) private returns (address) {
        Pan pan = new Pan();
        pan.initialize("PAN","PAN");
        pan.transferMinterBurnerRole(minterBurner);
        return address(pan);
    }

    function deployMirrorToken(address sourceAddress, string memory _name, string memory _symbol, uint _chainId, address axonNexus) internal returns (address) {
        USDMirror mirrorToken = new USDMirror();
        mirrorToken.initialize(_name, _symbol, _chainId);
        mirrorToken.transferMinterBurnerRole(axonNexus);
        StableTokenRegistry(axonNexus).registerMirrorToken(_chainId,sourceAddress,address(mirrorToken));
        console.log("Deploying token : ",_name);
        return address(mirrorToken);
    }

    function initializeAxonNexus(ConfigLib.DeployConfig memory config, ConfigLib.AxonNexusConfig memory axonConfig) internal{
        AxonMultiBridgeFacet(axonConfig.nexusDiamond).initMultiBridgeFacet(config.hyperlaneMailbox,config.hyperlaneMailbox,0);
        StableTokenRegistry(axonConfig.nexusDiamond).initTokenFactory(axonConfig.pan);
    }

    function initializeRemoteNexus(
        ConfigLib.DeployConfig memory config,
        ConfigLib.NexusConfig memory nexusConfig,
        address axon,
        uint chainIdAxon
    ) internal{
        CrossChainRouter(nexusConfig.nexusDiamond).initializeNexus(nexusConfig.pan,axon,chainIdAxon);
        HyperlaneFacet(nexusConfig.nexusDiamond).initHyperlaneFacet(config.hyperlaneMailbox,config.hyperlaneISM);
    }

    //--PSM--//
    function deployPSM(address _pan) private returns (address) {
        PanPSM psm = new PanPSM();
        psm.initialize(_pan);
        console.log("PSM deployed at - ", address(psm));
        return address(psm);
    }
}