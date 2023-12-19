// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IMultiSigWallet {
    function submitTransaction(address payable destination, address token, uint8 ts, uint tokenId, uint value, bytes memory data, uint confirmTimestamp) external returns (uint transactionId);
}
