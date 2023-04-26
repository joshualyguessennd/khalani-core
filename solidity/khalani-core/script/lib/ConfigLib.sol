// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;
import "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";

import {BytesLib} from "../lib/BytesLib.sol";
import "../DeployNexusMultiChain.s.sol";

library ConfigLib {
    using stdJson for string;
    using BytesLib for bytes;

    struct NexusConfig {
        string chainName;
        uint domainId;
        address kai;
        address psm;
        address nexusDiamond;
        address crossChainRouter;
        address hyperlaneFacet;
        address msgHandlerFacet;
    }

    struct AxonNexusConfig {
        string chainName;
        uint domainId;
        address kai;
        address nexusDiamond;
        address axonCrossChainRouter;
        address axonHandlerFacet;
        address axonMultiBridgeFacet;
        address stableTokenRegistry;
        address vortex;
    }

    struct DeployConfig {
        string chainName;
        uint chainId;
        string rpcUrl;
        address hyperlaneMailbox;
        address hyperlaneISM;
        address[] tokens;
    }

    function readDeployConfig(
        Vm vm,
        string memory chainName
    ) internal returns (DeployConfig memory deployConfig) {
        string memory json = vm.readFile("config/deploy_config.json");
        deployConfig.chainName = chainName;
        chainName = string.concat('.',chainName);
        deployConfig.chainId = vm.parseJsonUint(json, string.concat(chainName, ".chainId"));

        deployConfig.rpcUrl = vm.parseJsonString(json,string.concat(chainName, ".rpcUrl"));

        deployConfig.hyperlaneMailbox = vm.parseJsonAddress(json,string.concat(chainName,".hyperlaneMailbox"));

        deployConfig.hyperlaneISM = vm.parseJsonAddress(json,string.concat(chainName,".hyperlaneISM"));

        // Workaround for Forge parser error on empty array of addresses []
        bytes memory tokensAddressesBytes = vm.parseJson(json, string.concat(chainName, ".tokens"));
        uint256 numOfTokens = (tokensAddressesBytes.length - 64) / 32;
        if (numOfTokens > 0) {
            deployConfig.tokens = vm.parseJsonAddressArray(json, string.concat(chainName, ".tokens"));
        }

        console.log("Read DeployConfig for %s", chainName);
        console.log("  chainName = %s", deployConfig.chainName);
        console.log("  chainId = %s", deployConfig.chainId);
        console.log("  hyperlaneMailbox = %s", deployConfig.hyperlaneMailbox);
        console.log("  hyperlaneISM = %s", deployConfig.hyperlaneISM);
        console.log("  rpcUrl = %s", deployConfig.rpcUrl);
        console.log("  tokens.length = %s", deployConfig.tokens.length);
        for (uint i = 0; i < deployConfig.tokens.length; i++) {
            console.log("    token %s", deployConfig.tokens[i]);
        }
    }

    function readNexusConfig(
        Vm vm,
        string memory chainName,
        uint domainId
    ) internal returns (NexusConfig memory nexusConfig) {
        string memory json = vm.readFile("config/networks.json");

        nexusConfig.chainName = chainName;
        nexusConfig.domainId = domainId;

        nexusConfig.kai = vm.parseJsonAddress(json, string.concat(".", chainName, ".kai"));
        nexusConfig.psm = vm.parseJsonAddress(json, string.concat(".", chainName, ".psm"));
        nexusConfig.nexusDiamond = vm.parseJsonAddress(json, string.concat(".", chainName, ".nexusDiamond"));
        nexusConfig.crossChainRouter = vm.parseJsonAddress(json, string.concat(".", chainName, ".crossChainRouter"));
        nexusConfig.hyperlaneFacet = vm.parseJsonAddress(json, string.concat(".", chainName, ".hyperlaneFacet"));
        nexusConfig.msgHandlerFacet = vm.parseJsonAddress(json, string.concat(".", chainName, ".msgHandlerFacet"));

        console.log("Read NexusConfig for %s", chainName);
        console.log("  chainName = %s", nexusConfig.chainName);
        console.log("  chainId = %s", nexusConfig.domainId);
        console.log("  kai = %s", nexusConfig.kai);
        console.log("  psm = %s", nexusConfig.psm);
        console.log("  nexusDiamond = %s", nexusConfig.nexusDiamond);
        console.log("  hyperlaneFacet = %s", nexusConfig.hyperlaneFacet);
        console.log("  msgHandlerFacet = %s", nexusConfig.msgHandlerFacet);
        console.log("  crossChainRouter = %s", nexusConfig.crossChainRouter);
    }

    function readAxonNexusConfig(
        Vm vm,
        string memory axon,
        uint axonDomainId
    ) internal returns (AxonNexusConfig memory axonNexusConfig) {
        string memory json = vm.readFile("config/networks.json");

        axonNexusConfig.chainName = axon;
        axonNexusConfig.domainId = axonDomainId;

        axonNexusConfig.kai = vm.parseJsonAddress(json, string.concat(".", axon, ".kai"));
        axonNexusConfig.nexusDiamond = vm.parseJsonAddress(json, string.concat(".", axon, ".nexusDiamond"));
        axonNexusConfig.axonCrossChainRouter = vm.parseJsonAddress(json, string.concat(".", axon, ".axonCrossChainRouter"));
        axonNexusConfig.axonHandlerFacet = vm.parseJsonAddress(json, string.concat(".", axon, ".axonHandlerFacet"));
        axonNexusConfig.axonMultiBridgeFacet = vm.parseJsonAddress(json, string.concat(".", axon, ".axonMultiBridgeFacet"));
        axonNexusConfig.stableTokenRegistry = vm.parseJsonAddress(json, string.concat(".", axon, ".stableTokenRegistry"));
        axonNexusConfig.vortex = vm.parseJsonAddress(json, string.concat(".", axon, ".vortex"));

        console.log("Read AxonNexusConfig for %s", axon);
        console.log("  chainName = %s", axonNexusConfig.chainName);
        console.log("  chainId = %s", axonNexusConfig.domainId);
        console.log("  kai = %s", axonNexusConfig.kai);
        console.log("  nexusDiamond = %s", axonNexusConfig.nexusDiamond);
        console.log("  axonCrossChainRouter = %s", axonNexusConfig.axonCrossChainRouter);
        console.log("  axonHandlerFacet = %s", axonNexusConfig.axonHandlerFacet);
        console.log("  axonMultiBridgeFacet = %s", axonNexusConfig.axonMultiBridgeFacet);
        console.log("  stableTokenRegistry = %s", axonNexusConfig.stableTokenRegistry);
        console.log("  vortex = %s", axonNexusConfig.vortex);
    }

    function writeNexusConfig(NexusConfig memory config, Vm vm) internal {
        string memory contracts = string.concat("nexusContracts", ".", config.chainName);
        vm.serializeAddress(contracts,"kai",config.kai);
        vm.serializeAddress(contracts,"psm",config.psm);
        vm.serializeAddress(contracts,"nexusDiamond",config.nexusDiamond);
        vm.serializeAddress(contracts,"crossChainRouter",config.crossChainRouter);
        vm.serializeAddress(contracts,"hyperlaneFacet",config.hyperlaneFacet);
        string memory addresses = vm.serializeAddress(contracts,"msgHandlerFacet",config.msgHandlerFacet);
        vm.writeJson(addresses,"config/networks.json",string.concat('.',config.chainName));
    }

    function writeAxonNexusConfig(AxonNexusConfig memory config, Vm vm) internal {
        string memory contracts = "axonContracts";
        vm.serializeAddress(contracts,"kai",config.kai);
        vm.serializeAddress(contracts,"nexusDiamond",config.nexusDiamond);
        vm.serializeAddress(contracts,"axonCrossChainRouter",config.axonCrossChainRouter);
        vm.serializeAddress(contracts,"axonHandlerFacet",config.axonHandlerFacet);
        vm.serializeAddress(contracts,"axonMultiBridgeFacet",config.axonMultiBridgeFacet);
        vm.serializeAddress(contracts,"stableTokenRegistry",config.stableTokenRegistry);
        string memory axonAddresses = vm.serializeAddress(contracts,"vortex",config.vortex);
        vm.writeJson(axonAddresses,"config/networks.json",string.concat('.',config.chainName));
    }

    function prepareNetworksOutJson(string memory axon, string[] memory remotes, Vm vm) internal {
        string memory networks  = "networks";
        string memory json;
        vm.serializeString(networks,axon,"");
        for(uint i;i<remotes.length;){
            if(i==remotes.length-1){
                json = vm.serializeString(networks,remotes[i],"");

            }else{
                vm.serializeString(networks,remotes[i],"");
            }
            unchecked{
                ++i;
            }
        }
        vm.writeJson(json,"config/networks.json");
        vm.writeJson(json,"config/tokens.json");
    }

    function writeMirrorTokens(string memory chainName, address[] memory tokens, address[] memory mirrorTokens, Vm vm) internal{
        string memory tokensJson = string.concat("tokensJson", ".", chainName);
        vm.serializeAddress(tokensJson,"tokens",tokens);
        string memory addressArrays = vm.serializeAddress(tokensJson,"mirrorTokens",mirrorTokens);
        vm.writeJson(addressArrays,"config/tokens.json",string.concat('.',chainName));
    }
}
