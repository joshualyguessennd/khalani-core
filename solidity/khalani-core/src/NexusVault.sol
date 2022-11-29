// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/INexusVault.sol";
import "./balancer/vault/interfaces/IAsset.sol";

contract NexusVault is Ownable, ERC20 {
    using SafeMath for uint256;
    address public token0;
    address public token1;
    address public BPool;
    uint32 private blockTimestampLast;
    uint112 private amountTotalToken0;
    uint112 private amountTotalToken1;
    bytes4 private constant SELECTOR_TRANSFER =
        bytes4(keccak256(bytes("transfer(address,uint256)")));
    bytes4 private constant SELECTOR_JOINPOOL =
        bytes4(
            keccak256(
                bytes("joinPool(bytes32,address,address,JoinPoolRequest)")
            )
        );

    bytes4 private constant SELECTOR_EXITPOOL =
        bytes4(
            keccak256(
                bytes("exitPool(bytes32,address,address,JoinPoolRequest)")
            )
        );

    // store the balance of users
    // amountA represents token0
    // amountB represents token1
    struct UserBalance {
        uint256 amountA;
        uint256 amountB;
    }

    // each address that interact with the contract is mapped to UserBalance
    mapping(address => UserBalance) public userData;

    event Deposit(
        address indexed user,
        uint256 amountTokenA,
        uint256 amountTokenB,
        uint256 shares
    );

    event Withdrawn(
        address indexed user,
        uint256 amountTokenA,
        uint256 amountTokenB
    );

    constructor(
        address _token0,
        address _token1,
        address _BPool
    ) ERC20("Nexus", "NXS") {
        token0 = _token0;
        token1 = _token1;
        BPool = _BPool;
    }

    /**
     *@notice returns the reserve total of token0 and token1 present in the vault
     */
    function getReserves()
        public
        view
        returns (uint112 _reserveToken0, uint112 _reserveToken1)
    {
        _reserveToken0 = amountTotalToken0;
        _reserveToken1 = amountTotalToken1;
    }

    /**
    *@dev deposit token0 and token1 to the NexusVault
    @param _amountA, amount token0
    @param _amountB, amount token1
    */
    function deposit(uint256 _amountA, uint256 _amountB) external {
        uint256 amount0 = IERC20(token0).balanceOf(address(this));
        uint256 amount1 = IERC20(token1).balanceOf(address(this));
        uint256 amountA = userData[msg.sender].amountA;
        uint256 amountB = userData[msg.sender].amountB;
        // verify amount sent to the vault is valid
        require(_amountA + _amountB > 0, "Invalid Amounts");
        // following the amount , the transferFrom logici is adapted
        if (_amountA > 0 && _amountB == 0) {
            IERC20(token0).transferFrom(msg.sender, address(this), _amountA);
            amountA += _amountA;
        } else if (_amountB > 0 && _amountA == 0) {
            IERC20(token1).transferFrom(msg.sender, address(this), _amountB);
            amountB += _amountB;
        } else {
            IERC20(token0).transferFrom(msg.sender, address(this), _amountA);
            IERC20(token1).transferFrom(msg.sender, address(this), _amountB);
            amountA += _amountA;
            amountB += _amountB;
        }

        uint256 newAmount0 = amount0 + _amountA;
        uint256 newAmount1 = amount1 + _amountB;
        _updateReserves(newAmount0, newAmount1);
        //todo calculate share
        uint256 _shares = issueShare(_amountA, _amountB);
        Deposit(msg.sender, _amountA, _amountB, _shares);
    }

    /**
    @notice users call this function to withdraw amount by buring shares
    @param _shares, shares burnt
    */
    function withdraw(uint256 _shares) external {
        (uint256 amount0, uint256 amount1) = calcShareValue(_shares);
        uint256 amountA = userData[msg.sender].amountA;
        uint256 amountB = userData[msg.sender].amountB;
        _burn(msg.sender, _shares);
        if (amount0 > 0 && amount1 == 0) {
            _safeTransfer(token0, msg.sender, amount0);
            amountA -= amount0;
        } else if (amount1 > 0 && amount0 == 0) {
            _safeTransfer(token1, msg.sender, amount1);
            amountB -= amount1;
        } else {
            _safeTransfer(token0, msg.sender, amount0);
            _safeTransfer(token1, msg.sender, amount1);
            amountA -= amount0;
            amountB -= amount1;
        }
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        _updateReserves(balance0, balance1);
        Withdrawn(msg.sender, amount0, amount1);
    }

    // calculate and mint shares depending of the amount of token0 and token1 provided
    function issueShare(uint256 _amountA, uint256 _amountB)
        internal
        returns (uint256 shares)
    {
        uint256 _totalSupply = totalSupply();
        (uint112 _reserveToken0, uint112 _reserveToken1) = getReserves();
        if (_totalSupply == 0) {
            shares = sqrt(_amountA.mul(_amountB));
            _mint(msg.sender, shares);
        } else {
            shares = min(
                _amountA.mul(_totalSupply) / _reserveToken0,
                _amountB.mul(_totalSupply) / _reserveToken1
            );
        }
        require(shares > 0, "Insufficient Liquidity");
        _mint(msg.sender, shares);
    }

    // calculate shares value
    function calcShareValue(uint256 _shares)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 _totalSupply = totalSupply();
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        amount0 = _shares.mul(balance0) / _totalSupply;
        amount1 = _shares.mul(balance1) / _totalSupply;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }

    function _updateReserves(uint256 _amount0, uint256 _amount1) private {
        require(
            _amount0 <= uint112(-1) && _amount1 <= uint112(-1),
            "Nexus: OVERFLOW"
        );
        amountTotalToken0 = uint112(_amount0);
        amountTotalToken1 = uint112(_amount1);
    }

    function _safeTransfer(
        address token,
        address to,
        uint256 value
    ) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(SELECTOR_TRANSFER, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "NexusVault: TRANSFER_FAILED"
        );
    }

    // join balancer Pool
    function _joinBalancerPool(
        bytes32 poolId,
        address sender,
        address recipient,
        INexusVault.JoinPoolRequest memory request
    ) public {
        (bool success, bytes memory data) = BPool.call(
            abi.encodeWithSelector(
                SELECTOR_JOINPOOL,
                poolId,
                sender,
                recipient,
                request
            )
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "NexusVault: JOINPOOL_FAILED"
        );
    }

    // exit Balancer Pool
    function _exitBalancerPool(
        bytes32 poolId,
        address sender,
        address payable recipient,
        INexusVault.JoinPoolRequest memory request
    ) public {
        (bool success, bytes memory data) = BPool.call(
            abi.encodeWithSelector(
                SELECTOR_JOINPOOL,
                poolId,
                sender,
                recipient,
                request
            )
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "NexusVault: EXITPOOL_FAILED"
        );
    }
}
