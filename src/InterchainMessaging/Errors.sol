pragma solidity ^0.8.0;

//Nexus Errors
    error InvalidInbox();
    error InvalidNexus();
    error InvalidRouter();
    error InvalidHyperlaneAdapter();
    error NotValidOwner();
    error AssetNotFound(address token);
    error AssetNotWhiteListed(address token);
    error ZeroTargetAddress();
    error InvalidSender(bytes32 sender);
    error AssetNotSupported(address asset);
    error RedeemFailedNotEnoughBalance();
    error MulOverflow();
    error UnsupportedDecimals();