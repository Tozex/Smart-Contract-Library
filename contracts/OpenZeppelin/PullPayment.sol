pragma solidity ^0.8.1;

import "./SafeMath.sol";

// SPDX-License-Identifier: GPL-3.0
/**
 * @title PullPayment
 * @dev Base contract supporting async send for pull payments. Inherit from this
 * contract and use asyncSend instead of send.
 */
contract PullPayment {
    using SafeMath for uint256;

    mapping (address => uint256) public payments;

    uint256 public totalPayments;

    /**
    * @dev Called by the payer to store the sent amount as credit to be pulled.
    * @param dest The destination address of the funds.
    * @param amount The amount to transfer.
    */
    function asyncSend(address dest, uint256 amount) internal{
        payments[dest] = payments[dest].add(amount);
        totalPayments = totalPayments.add(amount);
    }

    /**
    * @dev withdraw accumulated balance, called by payee.
    */
    function withdrawPayments() internal{
        address payee = msg.sender;
        uint256 payment = payments[payee];

        require(payment != 0);
        require(address(this).balance >= payment);

        totalPayments = totalPayments.sub(payment);
        payments[payee] = 0;
        payable(msg.sender).transfer(payment);
    }
}
