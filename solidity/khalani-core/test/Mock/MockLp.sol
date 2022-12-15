pragma solidity ^0.8.0;

contract MockLp{
    address gap;
    mapping(address => uint) balance;
    bool fail; //when set true reverts call of add liquidity
    function addLiqiuidity2(uint256[2] calldata amounts) external returns(uint){
        if(fail){
            revert();
        }
        balance[msg.sender] = amounts[0]+amounts[1];
        return balance[msg.sender];
    }

    function addLiquidity(uint256 amount) external returns(uint){
        if(fail){
            revert();
        }
        balance[msg.sender] = amount;
        return amount;
    }

    function setFail(bool flag) public {
        fail = flag;
    }

    function balanceOf(address account) external returns (uint){
        return balance[account];
    }
}