pragma solidity ^0.8.1;

// SPDX-License-Identifier: GPL-3.0

interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address _owner) external view returns (uint256);



}
