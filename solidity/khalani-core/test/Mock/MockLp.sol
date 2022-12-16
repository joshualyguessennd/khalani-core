pragma solidity ^0.8.0;

import "./MockERC20.sol";

contract MockLp{
    address gap;
    mapping(address=>mapping(address => uint)) balance;
    bool fail; //when set true reverts call of add liquidity
    function addLiquidity2(address[2] calldata token, uint256[2] calldata amounts) external returns(uint[2] memory){
        if(fail){
            revert();
        }
        MockERC20(token[0]).transferFrom(msg.sender,address(this),amounts[0]);
        MockERC20(token[1]).transferFrom(msg.sender,address(this),amounts[1]);
        balance[token[0]][msg.sender] = amounts[0];
        balance[token[1]][msg.sender] = amounts[1];
        return (amounts);
    }

    function addLiquidity(address token, uint256 amount) external returns(uint){
        if(fail){
            revert();
        }
        MockERC20(token).transferFrom(msg.sender,address(this),amount);
        balance[token][msg.sender] = amount;
        return amount;
    }

    function setFail(bool flag) public {
        fail = flag;
    }

    function balanceOf(address token, address account) external returns (uint){
        return balance[token][account];
    }
}