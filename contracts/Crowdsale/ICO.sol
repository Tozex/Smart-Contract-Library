pragma solidity ^0.8.1;

import "../OpenZeppelin/SafeMath.sol";
import "../OpenZeppelin/Ownable.sol";
import "../OpenZeppelin/Pausable.sol";
import "../OpenZeppelin/SafeERC20.sol";

import "../Token/ERC20/IERC20.sol";


// SPDX-License-Identifier: GPL-3.0


/**
 * @title ICO
 * @dev ICO is a base contract for managing a public token sale,
 * allowing investors to purchase tokens with ether. This contract implements
 * such functionality in its most fundamental form and can be extended to provide additional
 * functionality and/or custom behavior.
 * The external interface represents the basic interface for purchasing tokens, and conform
 * the base architecture for a public sale. They are *not* intended to be modified / overriden.
 * The internal interface conforms the extensible and modifiable surface of public token sales. Override
 * the methods to add functionality. Consider using 'super' where appropiate to concatenate
 * behavior.
 */

contract ICO is  Ownable, Pausable {

  using SafeMath for uint256;
  using SafeERC20 for IERC20;
  
  struct UserDetail {
    uint256 depositAmount;
    uint256 totalRewardAmount;
    uint256 withdrawAmount;   
  }

  // The token being sold
  IERC20 public immutable token;

  // Dai token.
  IERC20 public immutable daiToken;
  // Decimals vlaue of the token
  uint256 tokenDecimals;

  // Address where funds are collected
  address public wallet;

  // How many token units a buyer gets per ETH/wei during ICO. The ETH price is fixed at 400$ during the ICO to guarantee the 30 % discount rate with the presale rate
  uint256 public icoRate;    //  1 DCASH Token = 10 DAI

  // Amount of Dai raised during the ICO period
  uint256 public totalDepositAmount;

  uint256 private pendingTokenToSend;

  // Minimum purchase size of incoming Dai token = 10$.
  uint256 public constant minPurchaseIco = 10 * 1e18;

  // Hardcap goal in Ether during ICO in Ether raised fixed at $ 13 000 000 for ETH valued at 400$
  uint256 public icoMaxCap;

  // Unlock time stamp.
  uint256 public unlockTime;

  // The percent that unlocked after unlocktime. 10%
  uint256 private firstUnlockPercent = 10; 

  // The percent that unlocked weekly. 20%
  uint256 private weeklyUnlockPercent = 20; 

  // 1 week as a timestamp.
  uint256 private oneWeek = 604800;
  
  // ICO start/end
  bool public ico = false;         // State of the ongoing sales ICO period

  // User deposit Dai amount
  mapping(address => UserDetail) public userDetails;

  event TokenPurchase(address indexed buyer, uint256 value, uint256 amount);
  event ClaimTokens(address indexed user, uint256 amount);
  /**
   * @param _wallet Address where collected funds will be forwarded to
   * @param _daiToken Address of Dai token
   * @param _token Address of reward token
   * @param _tokenDecimals The decimal of reward token
   * @param _icoRate How many token units a buy get per Dai token.
   */
  constructor(
    address _wallet,
    IERC20 _daiToken,
    IERC20 _token, 
    uint256 _tokenDecimals,
    uint256 _icoMaxCap,
    uint256 _icoRate
  ) {
    require(address(_daiToken) != address(0) && _wallet != address(0) && address(_token) != address(0));
    daiToken = _daiToken;
    wallet = _wallet;
    token = _token;
    tokenDecimals = _tokenDecimals;
    icoMaxCap = _icoMaxCap;
    icoRate = _icoRate;
    // start ico
    ico = true;
  }

  // -----------------------------------------
  // ICO external interface
  // -----------------------------------------


  /**
   * @dev low level token purchase ***DO NOT OVERRIDE***
   * @param _daiAmount Dai token amount
   */
  function buyTokens(uint256 _daiAmount) external whenNotPaused {
    require(ico, "ICO.buyTokens: ICO is already finished.");
    require(_daiAmount >= minPurchaseIco, "ICO.buyTokens: Failed the amount is not respecting the minimum deposit of ICO");

    if(totalDepositAmount.add(_daiAmount) > icoMaxCap) {
      _daiAmount = icoMaxCap.sub(totalDepositAmount);
    }    

    uint256 tokenAmount = _getTokenAmount(_daiAmount);

    require(token.balanceOf(address(this)).sub(pendingTokenToSend) >= tokenAmount, "ICO.buyTokens: not enough token to send");

    daiToken.transferFrom(msg.sender, wallet, _daiAmount);

    totalDepositAmount = totalDepositAmount.add(_daiAmount);

    pendingTokenToSend = pendingTokenToSend.add(tokenAmount);

    UserDetail storage userDetail = userDetails[msg.sender];
    userDetail.depositAmount = userDetail.depositAmount.add(_daiAmount);
    userDetail.totalRewardAmount = userDetail.totalRewardAmount.add(tokenAmount);

    emit TokenPurchase(msg.sender, _daiAmount, tokenAmount);

    //If icoMaxCap is reached then the ICO close
    if (totalDepositAmount >= icoMaxCap) {
      ico = false;
    }
  }

  function claimTokens(uint256 _amount) external {
    require(!ico, "ICO.claimTokens: ico is not finished yet.");

    uint256 unlocked = unlockedToken(msg.sender);
    require(unlocked >= _amount, "ICO.claimTokens: Not enough token to withdraw.");

    UserDetail storage user = userDetails[msg.sender];

    user.withdrawAmount = user.withdrawAmount.add(_amount);
    pendingTokenToSend = pendingTokenToSend.sub(_amount);

    token.transfer(msg.sender, _amount);

    emit ClaimTokens(msg.sender, _amount);
  }

  /* ADMINISTRATIVE FUNCTIONS */

  // Update the ETH ICO rate
  function updateIcoRate(uint256 _icoRate) external onlyOwner {
    icoRate = _icoRate;
  }

  // Update the ETH ICO MAX CAP
  function updateIcoMaxCap(uint256 _icoMaxCap) external onlyOwner {
    icoMaxCap = _icoMaxCap;
  }

 // start/close Ico
  function setIco(bool status) external onlyOwner {
    ico = status;
  }

  // Update the ETH ICO rate
  function updateUnlockTime(uint256 _unlockTime) external onlyOwner {
    require(_unlockTime >= _getNow(), "ICO.updateUnlockTime: Can't set prev time as a unlock time");
    unlockTime = _unlockTime;
  }

  // -----------------------------------------
  // View functions
  // -----------------------------------------

   function unlockedToken(address _user) public view returns (uint256) {
      UserDetail storage user = userDetails[_user];

      if(unlockTime == 0) {
          return 0;
      }
      else if (_getNow() < unlockTime) {
          return 0;
      }
      else {
          uint256 timePassed = _getNow().sub(unlockTime);
          uint256 weekPassed = timePassed.div(oneWeek);
          uint256 unlocked;
          if(weekPassed >= 5){
              unlocked = user.totalRewardAmount;
          } else {
              uint256 unlockedPercent = (weeklyUnlockPercent.mul(weekPassed)).add(firstUnlockPercent);
              unlocked = user.totalRewardAmount.mul(unlockedPercent).div(100);
          }
          return unlocked.sub(user.withdrawAmount);
      }
  }

  // Calcul the amount of token the benifiaciary will get by buying during Sale
  function _getTokenAmount(uint256 _daiAmount) internal view returns (uint256) {
    uint256 _amountToSend = _daiAmount.mul(10 ** tokenDecimals).div(icoRate);
    return _amountToSend;
  }

  function _getNow() public virtual view returns (uint256) {
      return block.timestamp;
  }

}
