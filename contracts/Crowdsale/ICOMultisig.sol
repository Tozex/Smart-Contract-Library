pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../MultiSigWallet/IMultiSigWallet.sol";

// SPDX-License-Identifier: GPL-3.0


/**
 * @title ICOStablecoin
 * @dev ICO is a base contract for managing a public token sale,
 * allowing investors to purchase tokens with Stablecoin. This contract implements
 * such functionality in its most fundamental form and can be extended to provide additional
 * functionality and/or custom behavior.
 * The external interface represents the basic interface for purchasing tokens, and conform
 * the base architecture for a public sale. They are *not* intended to be modified / overriden.
 * The internal interface conforms the extensible and modifiable surface of public token sales. Override
 * the methods to add functionality. Consider using 'super' where appropiate to concatenate
 * behavior.
 */

contract ICOMultisig is  Initializable, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {

  using SafeMath for uint256;
  using SafeERC20 for IERC20;
  
  struct UserDetail {
    TokenType tt;
    uint256 depositAmount;
    uint256 totalRewardAmount;
    uint256 remainingAmount;
  }

  enum TokenType {
    TOZ,
    USDC
  }
  
  // The token being sold
  IERC20 public token;

  // Stablecoin token.
  IERC20 public tozToken;

  // Stablecoin token.
  IERC20 public usdcToken;

  IMultiSigWallet public multisig;
  // TOZ : DPS Ratio
  uint256 tozRatio;

  // USDC : DPS Ratio
  uint256 usdcRatio;

  // Amount of Stablecoin raised during the ICO period
  uint256 public totalDepositAmount;

  // Minimum purchase size of incoming Stablecoin token = 10$.
  uint256 public constant minPurchaseIco = 10 * 1e18;

  // Hardcap goal in Stablecoin during ICO in Stablecoin 
  uint256 public icoMaxCap;

  // Softcap goal in Stablecoin during ICO in Stablecoin 
  uint256 public icoSoftCap;

  // Unlock time stamp.
  uint256 public unlockTime;

  // ICO start/end
  bool public ico = false;         // State of the ongoing sales ICO period

  // User deposit Stablecoin amount
  mapping(address => UserDetail) public userDetails;
  address[] public userAddresses;

  event TokenPurchase(address indexed buyer, uint256 value, uint256 amount);
  event WithdrawStablecoin(address indexed sender, address indexed recipient, uint256 amount);
  event WithdrawTozToken(address indexed sender, address indexed recipient, uint256 amount);
  event WithdrawToken(address indexed sender, address indexed recipient, uint256 amount);
  event UpdateTozRatio(uint256 tozRatio);
  event UpdateUsdcRatio(uint256 usdcRatio);
  event UpdateIcoSoftCap(uint256 icoSoftCap);
  event UpdateIcoMaxCap(uint256 icoMaxCap);
  event SetUnlockTime(uint256 unlockTime);
  event SetIco(bool status);
  event SetMultisig(address indexed multisig);

  /**
   * @param _tozToken Address of Stablecoin token
   * @param _usdcToken Address of Stablecoin token
   * @param _token Address of reward token
   * @param _tozRatio The token ratio btw TOZ and DPS
   * @param _usdcRatio The token ratio btw USDC and DPS
   * @param _icoSoftCap The softcap amount of DPS token.
   * @param _icoMaxCap The maxcap amount of DPS token.
   */
  function initialize(
    IERC20 _tozToken,
    IERC20 _usdcToken,
    IERC20 _token, 
    uint256 _tozRatio,
    uint256 _usdcRatio,
    uint256 _icoSoftCap,
    uint256 _icoMaxCap
  ) external initializer {
    __Context_init();
    __Ownable_init();
    __Pausable_init();

    require(address(_usdcToken) != address(0) && address(_tozToken) != address(0) && address(_token) != address(0));
    tozToken = _tozToken;
    usdcToken = _usdcToken;
    token = _token;
    tozRatio = _tozRatio;
    usdcRatio = _usdcRatio;
    icoSoftCap = _icoSoftCap;
    icoMaxCap = _icoMaxCap;

    // start ico
    ico = true;
  }

  // -----------------------------------------
  // ICO external interface
  // -----------------------------------------


  /**
   * @dev low level token purchase ***DO NOT OVERRIDE***
   * @param _amount Stablecoin token amount
   */
  function buyTokens(TokenType _tt, uint256 _amount) external whenNotPaused nonReentrant {
    require(ico, "ICO.buyTokens: ICO is already finished.");
    require(unlockTime == 0 || _getNow() < unlockTime, "ICO.buyTokens: Buy period already finished.");

    uint256 tokenAmount = getTokenAmount(_tt, _amount);

    require(tokenAmount >= minPurchaseIco, "ICO.buyTokens: Failed the amount is not respecting the minimum deposit of ICO");
    require(totalDepositAmount + tokenAmount <= icoMaxCap, "ICO.buyTokens: Failed the hardcap is reached");

    IERC20 payToken = _tt == TokenType.TOZ ? tozToken : usdcToken;
    payToken.safeTransferFrom(msg.sender, address(multisig), _amount);

    UserDetail storage userDetail = userDetails[msg.sender];

    if(userDetail.depositAmount == 0)
      userAddresses.push(msg.sender);
    else if (userDetail.tt != _tt)
      revert("You already selected another token for payment");

    userDetail.tt = _tt;
    userDetail.depositAmount = userDetail.depositAmount + _amount;
    userDetail.totalRewardAmount = userDetail.totalRewardAmount + tokenAmount;
    userDetail.remainingAmount = userDetail.remainingAmount + tokenAmount;

    emit TokenPurchase(msg.sender, _amount, tokenAmount);

    if (totalDepositAmount >= icoSoftCap) {
      token.safeTransfer(msg.sender, tokenAmount);
      userDetail.remainingAmount = 0;
    }
    //If icoSoftCap is reached then then distribute all tokens
    else if (totalDepositAmount + tokenAmount >= icoSoftCap) {
      _distributeToken();
    }
    totalDepositAmount += tokenAmount;
    //If icoMaxCap is reached then the ICO close
    if (totalDepositAmount >= icoMaxCap) {
      ico = false;
    }
  }


  /* ADMINISTRATIVE FUNCTIONS */
  function pause() external onlyOwner() {
    _pause();
  }

  function unpause() external onlyOwner() {
    _unpause();
  }
  // Update the toz ICO rate
  function updateTozRatio(uint256 _tozRatio) external onlyOwner {
    tozRatio = _tozRatio;
    emit UpdateTozRatio(_tozRatio);
  }

  // Update the usdc ICO rate
  function updateUsdcRatio(uint256 _usdcRatio) external onlyOwner {
    usdcRatio = _usdcRatio;
    emit UpdateUsdcRatio(_usdcRatio);
  }

  // Update the token ICO SOFT CAP
  function updateIcoSoftCap(uint256 _icoSoftCap) external onlyOwner {
    icoSoftCap = _icoSoftCap;
    emit UpdateIcoSoftCap(_icoSoftCap);
  }

  // Update the token ICO MAX CAP
  function updateIcoMaxCap(uint256 _icoMaxCap) external onlyOwner {
    icoMaxCap = _icoMaxCap;
    emit UpdateIcoMaxCap(_icoMaxCap);
  }

 // start/close Ico
  function setIco(bool status) external onlyOwner {
    ico = status;
    emit SetIco(status);
  }

  function setMultisig(IMultiSigWallet _multisig) external onlyOwner {
    multisig = _multisig;
    emit SetMultisig(address(_multisig));
  }

  function setUnlockTime(uint256 _unlockTime) external onlyOwner {
    unlockTime = _unlockTime;
    emit SetUnlockTime(_unlockTime);
  }

  function requestRefund() external onlyOwner {
    uint256 tozBalance = tozToken.balanceOf(address(multisig));
    uint256 usdcBalance = usdcToken.balanceOf(address(multisig));
    multisig.submitTransaction(payable(address(this)), address(tozToken), 0, 0, tozBalance, "", 0);
    multisig.submitTransaction(payable(address(this)), address(usdcToken), 0, 0, usdcBalance, "", 0);
  }
  
  function refundToken() external nonReentrant onlyOwner {
    for(uint256 i = 0; i < userAddresses.length;) {
      UserDetail storage userDetail = userDetails[userAddresses[i]];
      IERC20 payToken = userDetail.tt == TokenType.TOZ ? tozToken : usdcToken;
      if(userDetail.depositAmount > 0) {
        payToken.safeTransfer(userAddresses[i], userDetail.depositAmount);
        userDetail.depositAmount = 0;
        userDetail.totalRewardAmount = 0;
        userDetail.remainingAmount = 0;
      }
      
      unchecked {
        i++;
      }
    }
  }

  function _distributeToken() internal {
    for(uint256 i = 0; i < userAddresses.length;) {
      UserDetail storage userDetail = userDetails[userAddresses[i]];
      if(userDetail.remainingAmount > 0) {
        token.safeTransfer(userAddresses[i], userDetail.remainingAmount);
        userDetail.remainingAmount = 0;
      }
      
      unchecked {
        i++;
      }
    }
  }

  //Withdraw remaining Stablecoin
  function withdrawStablecoin(address wallet) external onlyOwner {
    uint256 StablecoinBalance = usdcToken.balanceOf(address(this));
    usdcToken.safeTransfer(wallet, StablecoinBalance);
    emit WithdrawStablecoin(address(this), wallet, StablecoinBalance);
  }

  //Withdraw remaining Toz Token
  function withdrawTozToken(address wallet) external onlyOwner {
    uint256 TozTokenBalance = tozToken.balanceOf(address(this));
    tozToken.safeTransfer(wallet, TozTokenBalance);
    emit WithdrawTozToken(address(this), wallet, TozTokenBalance);
  }

  //Withdraw remaining token
  function withdrawToken(address wallet) external onlyOwner {
    uint256 TokenBalance = token.balanceOf(address(this));
    token.safeTransfer(wallet, TokenBalance);
    emit WithdrawToken(address(this), wallet, TokenBalance);
  }

  // Calcul the amount of token the benifiaciary will get by buying during Sale
  function getTokenAmount(TokenType _tt, uint256 _amount) public view returns (uint256) {
    uint256 ratio = _tt == TokenType.TOZ ? tozRatio : usdcRatio;
    uint256 decimal = _tt == TokenType.TOZ ? 18 : 6;
    uint256 _amountToSend = _amount * 100 * 10 ** (18 - decimal) / ratio;
    return _amountToSend;
  }

  function _getNow() public virtual view returns (uint256) {
      return block.timestamp;
  }

}
