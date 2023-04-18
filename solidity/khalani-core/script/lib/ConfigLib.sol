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
        address owner;
        address hyperlaneMailbox;
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
        address owner;
        address hyperlaneMailbox;
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
        console.log(json);
        chainName = string.concat('.',chainName);
        deployConfig.chainId = vm.parseJsonUint(json, string.concat(chainName, ".chainId"));

        deployConfig.rpcUrl = vm.parseJsonString(json,string.concat(chainName, ".rpcUrl"));

        deployConfig.hyperlaneMailbox = vm.parseJsonAddress(json,string.concat(chainName,".hyperlaneMailbox"));

        deployConfig.hyperlaneISM = vm.parseJsonAddress(json,string.concat(chainName,".hyperlaneISM"));

        deployConfig.tokens = vm.parseJsonAddressArray(json,string.concat(chainName, ".tokens"));
    }

    function writeNexusConfig(NexusConfig memory config, Vm vm) internal {
        string memory contracts = "contracts";
        vm.serializeAddress(contracts,"kai",config.kai);
        vm.serializeAddress(contracts,"psm",config.psm);
        vm.serializeAddress(contracts,"nexusDiamond",config.nexusDiamond);
        vm.serializeAddress(contracts,"crossChainRouter",config.crossChainRouter);
        vm.serializeAddress(contracts,"hyperlaneFacet",config.hyperlaneFacet);
        string memory addresses = vm.serializeAddress(contracts,"msgHandlerFacet",config.msgHandlerFacet);
        vm.writeJson(addresses,"config/networks.json",string.concat('.',config.chainName));
    }

    function writeAxonNexusConfig(AxonNexusConfig memory config, Vm vm) internal {
        string memory contracts = "contracts";
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
    }
}
