pragma solidity ^0.8.1;

import "../OpenZeppelin/SafeMath.sol";
import "../OpenZeppelin/Ownable.sol";
import "../OpenZeppelin/Pausable.sol";
import "../OpenZeppelin/SafeERC20.sol";

import "../Token/ERC20/IERC20.sol";


// SPDX-License-Identifier: GPL-3.0


/**
 * @title ICOStabelcoin
 * @dev ICO is a base contract for managing a public token sale,
 * allowing investors to purchase tokens with Stabelcoin. This contract implements
 * such functionality in its most fundamental form and can be extended to provide additional
 * functionality and/or custom behavior.
 * The external interface represents the basic interface for purchasing tokens, and conform
 * the base architecture for a public sale. They are *not* intended to be modified / overriden.
 * The internal interface conforms the extensible and modifiable surface of public token sales. Override
 * the methods to add functionality. Consider using 'super' where appropiate to concatenate
 * behavior.
 */

contract ICORanging is  Ownable, Pausable {

  using SafeMath for uint256;
  using SafeERC20 for IERC20;
  
  struct UserDetail {
    uint256 depositAmount;
    uint256 totalRewardAmount;
  }

  // The token being sold
  IERC20 public immutable token;

  // Stabelcoin token.
  IERC20 public immutable StabelcoinToken;
  // Decimals vlaue of the token
  uint256 tokenDecimals;

  // Address where funds are collected
  address public wallet;

  // Amount of Stabelcoin raised during the ICO period
  uint256 public totalDepositAmount;

  uint256 private pendingTokenToSend;

  // Hardcap goal in Stabelcoin during ICO in Stabelcoin raised fixed at $ 13 000 000 for Stabelcoin valued at 400$
  uint256 public icoMaxCap;

  // Unlock time stamp.
  uint256 public unlockTime;
  
  // Busd price of token
  uint256 public tokenPrice;

  // Minimum purchase size of incoming Stabelcoin token = 10$.
  uint256 public constant minPurchaseIco = 10 * 1e18;

  // First stage busd price per token. 0.5 busd
  uint256 public constant firstStagePrice = 5 * 1e17;

  // Frist stage busd amount. 50000 busd
  uint256 public constant firstStageAmount = 50000 * 1e18;

  // Second stage busd price per token. 0.35 busd
  uint256 public constant secondStagePrice = 35 * 1e16;

  // Second stage busd amount. 100000 busd
  uint256 public constant secondStageAmount = 100000 * 1e18;

  // Third stage busd price per token. 0.25 busd
  uint256 public constant thirdStagePrice = 25 * 1e16;

  // Third stage busd amount. 500000 busd
  uint256 public constant thirdStageAmount = 500000 * 1e18;

  // Last stage busd price per token. 0.15 busd
  uint256 public constant lastStagePrice = 15 * 1e16;

  // ICO start/end
  bool public ico = false;         // State of the ongoing sales ICO period

  // User deposit Stabelcoin amount
  mapping(address => UserDetail) public userDetails;

  event TokenPurchase(address indexed buyer, uint256 value, uint256 amount);
  event WithdrawStabelcoin(address indexed sender, address indexed recipient, uint256 amount);
  /**
   * @param _wallet Address where collected funds will be forwarded to
   * @param _StabelcoinToken Address of Stabelcoin token
   * @param _token Address of reward token
   * @param _tokenDecimals The decimal of reward token
   */
  constructor(
    address _wallet,
    IERC20 _StabelcoinToken,
    IERC20 _token, 
    uint256 _tokenDecimals,
    uint256 _icoMaxCap
  ) {
    require(address(_StabelcoinToken) != address(0) && _wallet != address(0) && address(_token) != address(0));
    StabelcoinToken = _StabelcoinToken;
    wallet = _wallet;
    token = _token;
    tokenDecimals = _tokenDecimals;
    icoMaxCap = _icoMaxCap;
    // start ico
    ico = true;
  }

  // -----------------------------------------
  // ICO external interface
  // -----------------------------------------


  /**
   * @dev low level token purchase ***DO NOT OVERRIDE***
   * @param _StabelcoinAmount Stabelcoin token amount
   */
  function buyTokens(uint256 _StabelcoinAmount) external whenNotPaused {
    require(ico, "ICO.buyTokens: ICO is already finished.");
    require(unlockTime == 0 || _getNow() < unlockTime, "ICO.buyTokens: Buy period already finished.");
    require(_StabelcoinAmount >= minPurchaseIco, "ICO.buyTokens: Failed the amount is not respecting the minimum deposit of ICO");

    if(totalDepositAmount.add(_StabelcoinAmount) > icoMaxCap) {
      _StabelcoinAmount = icoMaxCap.sub(totalDepositAmount);
    }    

    uint256 tokenAmount = _getTokenAmount(_StabelcoinAmount);

    require(token.balanceOf(address(this)) >= tokenAmount, "ICO.buyTokens: not enough token to send");

    StabelcoinToken.safeTransferFrom(msg.sender, wallet, _StabelcoinAmount);

    totalDepositAmount = totalDepositAmount.add(_StabelcoinAmount);

    token.safeTransfer(msg.sender, tokenAmount);

    UserDetail storage userDetail = userDetails[msg.sender];
    userDetail.depositAmount = userDetail.depositAmount.add(_StabelcoinAmount);
    userDetail.totalRewardAmount = userDetail.totalRewardAmount.add(tokenAmount);

    emit TokenPurchase(msg.sender, _StabelcoinAmount, tokenAmount);

    //If icoMaxCap is reached then the ICO close
    if (totalDepositAmount >= icoMaxCap) {
      ico = false;
    }
  }


  /* ADMINISTRATIVE FUNCTIONS */

  // Update the Stabelcoin ICO MAX CAP
  function updateIcoMaxCap(uint256 _icoMaxCap) external onlyOwner {
    icoMaxCap = _icoMaxCap;
  }

 // start/close Ico
  function setIco(bool status) external onlyOwner {
    ico = status;
  }

  // Withdraw Stabelcoin amount in the contract
  function withdrawStabelcoin() external onlyOwner {
    uint256 StabelcoinBalance = StabelcoinToken.balanceOf(address(this));
    StabelcoinToken.safeTransfer(wallet, StabelcoinBalance);
    emit WithdrawStabelcoin(address(this), wallet, StabelcoinBalance);
  }
  
  // Calcul the amount of token the benifiaciary will get by buying during Sale
  function _getTokenAmount(uint256 _StabelcoinAmount) internal returns (uint256) {
    uint256 decimals = 10 ** tokenDecimals;
    uint256 rewardTokenAmount;
    if (totalDepositAmount < firstStageAmount && firstStageAmount.sub(totalDepositAmount) <= _StabelcoinAmount) {
        uint256 amount = firstStageAmount.sub(totalDepositAmount);
        uint256 amountLeft = _StabelcoinAmount.sub(amount);
        rewardTokenAmount = amount.mul(decimals).div(firstStagePrice) + amountLeft.mul(decimals).div(secondStagePrice);
        tokenPrice = secondStagePrice;
    }
    else if (totalDepositAmount < secondStageAmount && secondStageAmount.sub(totalDepositAmount) <= _StabelcoinAmount) {
        uint256 amount = secondStageAmount.sub(totalDepositAmount);
        uint256 amountLeft = _StabelcoinAmount.sub(amount);
        rewardTokenAmount = amount.mul(decimals).div(secondStagePrice) + amountLeft.mul(decimals).div(thirdStagePrice);
        tokenPrice = thirdStagePrice;
    } 
    else if (totalDepositAmount < thirdStageAmount && thirdStageAmount.sub(totalDepositAmount) <= _StabelcoinAmount) {
        uint256 amount = thirdStageAmount.sub(totalDepositAmount);
        uint256 amountLeft = _StabelcoinAmount.sub(amount);
        rewardTokenAmount = amount.mul(decimals).div(thirdStagePrice) + amountLeft.mul(decimals).div(lastStagePrice);
        tokenPrice = lastStagePrice;
    }
    else {
        rewardTokenAmount = _StabelcoinAmount.mul(1e18).div(tokenPrice);
    }
    
    return rewardTokenAmount;
  }

  function _getNow() public virtual view returns (uint256) {
      return block.timestamp;
  }

}
