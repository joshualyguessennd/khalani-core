pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../src/InterchainMessaging/Errors.sol";
import "@hyperlane-xyz/core/contracts/mock/MockMailbox.sol";
import "../src/InterchainMessaging/adapters/HyperlaneAdapter.sol";
import "./Mock/MockNexus.sol";
import "@hyperlane-xyz/core/contracts/test/TestMultisigIsm.sol";

//unit tests for HyperlaneAdapter.sol
contract HyperlaneAdapterTest is Test {
    event ProcessRequestCalled(
        uint256 _origin,
        bytes32 _sender,
        bytes _message
    );

    MockMailbox mailboxChain1;
    address ismChain1;
    address nexusChain1;

    MockMailbox mailboxChain2;
    address ismChain2;
    address nexusChain2;

    function setUp() public {
        mailboxChain1 = new MockMailbox(1);
        mailboxChain2 = new MockMailbox(2);
        mailboxChain1.addRemoteMailbox(2, mailboxChain2);
        mailboxChain2.addRemoteMailbox(1, mailboxChain1);
        ismChain1 = address(new TestMultisigIsm());
        ismChain2 = address(new TestMultisigIsm());


        nexusChain1 = address(new MockNexus());
        nexusChain2 = address(new MockNexus());
    }

    function test_relayMessage_Access() public{
        HyperlaneAdapter adapterChain1 = new HyperlaneAdapter(address(mailboxChain1), ismChain1, nexusChain1);
        vm.expectRevert(InvalidNexus.selector);
        adapterChain1.relayMessage(2, TypeCasts.addressToBytes32(address(vm.addr(3))), abi.encodePacked("Hello"));
    }

    function test_handle_Access() public{
        HyperlaneAdapter adapterChain1 = new HyperlaneAdapter(address(mailboxChain1), ismChain1, nexusChain1);
        vm.expectRevert(InvalidInbox.selector);
        adapterChain1.handle(1, TypeCasts.addressToBytes32(address(vm.addr(3))), abi.encodePacked("Hello"));
    }

    function test_relayMessage_handle() public {
        HyperlaneAdapter adapterChain1 = new HyperlaneAdapter(address(mailboxChain1), ismChain1, nexusChain1);
        HyperlaneAdapter adapterChain2 = new HyperlaneAdapter(address(mailboxChain2), ismChain2, nexusChain2);

        //send message from chain 1 to chain 2
        vm.prank(nexusChain1);
        adapterChain1.relayMessage(2, TypeCasts.addressToBytes32(address(adapterChain2)), abi.encodePacked("Hello"));
        vm.expectEmit(nexusChain2);
        emit ProcessRequestCalled(uint256(1), TypeCasts.addressToBytes32(address(adapterChain1)), abi.encodePacked("Hello"));
        mailboxChain2.processNextInboundMessage();
    }
}