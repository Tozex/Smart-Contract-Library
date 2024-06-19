pragma solidity ^0.8.26;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../contracts/IMultiSigWallet.sol";

// SPDX-License-Identifier: GPL-3.0

/**
 * @title ICO CONTRACT using Multisig Wallet to safe the collected fund,
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

contract ICOMultisig is Pausable {
 
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
  IERC20 public immutable token;

  // Stablecoin token.
  IERC20 public immutable tozToken;

  // Stablecoin token.
  IERC20 public immutable usdcToken;

  IMultiSigWallet public multisig;

  // TOZ : Token Ratio
  uint256 tozRatio;

  // USDC : Token Ratio
  uint256 usdcRatio;

  // Decimals vlaue of the reward token
  uint256 tokenDecimal;

  // Decimals vlaue of the token
  uint256 usdcDecimal;

  // Address of tozex admin
  address public wallet; 

  // Amount of Stablecoin raised during the ICO period
  uint256 public totalDepositAmount;

  uint256 private pendingTokenToSend;

  // Hardcap goal in Stablecoin during ICO in Stablecoin 
  uint256 public icoMaxCap;

  // Softcap goal in Stablecoin during ICO in Stablecoin 
  uint256 public icoSoftCap;

  // Unlock time stamp.
  uint256 public unlockTime;

  // ICO start/end
  bool public ico = true;         // State of the ongoing sales ICO period

  // User deposit Stablecoin amount
  mapping(address => UserDetail) public userDetails;
  address[] public userAddresses;

  event TokenPurchase(address indexed buyer, uint256 value, uint256 amount);
  event WithdrawStablecoin(address indexed sender, address indexed recipient, uint256 amount);
  event WithdrawToztoken(address indexed sender, address indexed recipient, uint256 amount);
  event Withdrawtoken(address indexed sender, address indexed recipient, uint256 amount);
  event UpdateTozexAdminWallet(address indexed previousTozexAdmin, address indexed newTozexAdmin);
  event RefundExecuted(address indexed sender, address indexed buyer, uint256 amount);
  event TokenDistributed(address indexed sender, address indexed buyer, uint256 amount);
  event RefundRequested(address indexed sender, address indexed multisig, uint256 tozBalance, uint256 usdcBalance);


  /**
   * @param _tozToken Address of Stablecoin token
   * @param _usdcToken Address of Stablecoin token
   * @param _token Address of reward token
   * @param _tozRatio The token ratio btw TOZ and reward Token
   * @param _usdcRatio The token ratio btw USDC and reward Token
   * @param _usdcRatio The token ratio btw USDC and reward Token
   * @param _usdcDecimal The decimal of the USDC stabelcoin
   * @param _tokenDecimal The decimal of reward token
   * @param _icoSoftCap The softcap amount of reward token.
   * @param _icoMaxCap The maxcap amount of reward token.
   */

  constructor(
    IERC20 _tozToken,
    IERC20 _usdcToken,
    IERC20 _token, 
    address _wallet,
    uint256 _tozRatio,
    uint256 _usdcRatio,
    uint256 _usdcDecimal,
    uint256 _tokenDecimal,
    uint256 _icoSoftCap,
    uint256 _icoMaxCap
  ) {
    require(address(_usdcToken) != address(0) && address(_tozToken) != address(0) && address(_token) != address(0));
    tozToken = _tozToken;
    usdcToken = _usdcToken;
    token = _token;
    wallet = _wallet;
    tozRatio = _tozRatio; /* multiple by 100 to manage decimals eg ( 1 toz per token equal to 100) */
    usdcRatio = _usdcRatio; /* multiple by 100 to manage decimals eg ( 0.5 usdc per token equal to 50) */
    usdcDecimal = _usdcDecimal;
    tokenDecimal = _tokenDecimal;
    icoSoftCap = _icoSoftCap;
    icoMaxCap = _icoMaxCap;

  }

  modifier onlyTozex() {
        require(msg.sender == wallet, "Not authorized operation");
        _;
    }

  // -----------------------------------------
  // ICO external interface
  // -----------------------------------------


  /**
   * @dev low level token purchase ***DO NOT OVERRIDE***
   * @param _amount Stablecoin token amount
   */
  function buyTokens(TokenType _tt, uint256 _amount) external whenNotPaused {
    uint256 decimal = _tt == TokenType.TOZ ? 18 : usdcDecimal;
    require(ico, "ICO.buyTokens: ICO is already finished.");
    require(unlockTime == 0 || _getNow() < unlockTime, "ICO.buyTokens: Buy period already finished.");
    require(_amount >= 10 * 10** (decimal), "ICO.buyTokens: Failed the amount is not respecting the minimum deposit of ICO");   // Minimum purchase size of incoming Stablecoin token = 10$.

    uint256 tokenAmount = _getTokenAmount(_tt, _amount);

    require(totalDepositAmount + tokenAmount <= icoMaxCap, "ICO.buyTokens: Failed the hardcap is reached");
    require(token.balanceOf(address(this)) >= totalDepositAmount + tokenAmount, "ICO.buyTokens: not enough token to send");

    IERC20 payToken = _tt == TokenType.TOZ ? tozToken : usdcToken;
    payToken.safeTransferFrom(msg.sender, address(multisig), _amount);

    totalDepositAmount += tokenAmount;

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

    //If icoSoftCap is reached then then distribute all tokens
    if (totalDepositAmount >= icoSoftCap) {
      _distributeToken();
    }

    //If icoMaxCap is reached then the ICO close
    if (totalDepositAmount >= icoMaxCap) {
      ico = false;
    }
  }

  /* ADMINISTRATIVE FUNCTIONS */

  // Update the toz ICO rate
  function updateTozRatio(uint256  _tozRatio) external onlyTozex {
    tozRatio = _tozRatio;
  }

  // Update the usdc ICO rate
  function updateUsdcRatio(uint256 _usdcRatio) external onlyTozex {
    usdcRatio = _usdcRatio;
  }

  // Update the token ICO SOFT CAP
  function updateIcoSoftCap(uint256 _icoSoftCap) external onlyTozex  {
    icoSoftCap = _icoSoftCap;
  }

  // Update the token ICO MAX CAP
  function updateIcoMaxCap(uint256 _icoMaxCap) external onlyTozex {
    icoMaxCap = _icoMaxCap;
  }

 // start/close Ico
  function setIco(bool status) external onlyTozex {
    ico = status; // true = 1 or false = 0
  }

  function setMultisig(IMultiSigWallet _multisig) external onlyTozex { 
    require( _multisig != IMultiSigWallet(address(0)), "Address shouldn't be zero");
    multisig = _multisig;
  }

  function UpdateTozexAdmin(address newTozexAdmin) public onlyTozex {
      require(newTozexAdmin != address(0), "Address shouldn't be zero");
      emit UpdateTozexAdminWallet(wallet, newTozexAdmin);
      wallet = newTozexAdmin;
    }

  function requestRefund() external {
    require(ico != true, "ICO is running, please close it");
    require(unlockTime == 0 || _getNow() > unlockTime, "Buying period is not finished, please wait it.");
    uint256 tozBalance = tozToken.balanceOf(address(multisig));
    uint256 usdcBalance = usdcToken.balanceOf(address(multisig));
    multisig.submitTransaction(payable(address(this)), address(tozToken), 0, 0, tozBalance, "", 0);
    multisig.submitTransaction(payable(address(this)), address(usdcToken), 0, 0, usdcBalance, "", 0);
    emit RefundRequested(address(this), address(multisig), tozBalance, usdcBalance);

  }
  
  function refundToken() external onlyTozex {
    for(uint256 i = 0; i < userAddresses.length;) {
      UserDetail storage userDetail = userDetails[userAddresses[i]];
      IERC20 payToken = userDetail.tt == TokenType.TOZ ? tozToken : usdcToken;
      if(userDetail.depositAmount > 0) {
        payToken.safeTransfer(userAddresses[i], userDetail.depositAmount);
        userDetail.depositAmount = 0;
        userDetail.totalRewardAmount = 0;
        userDetail.remainingAmount = 0;
        emit RefundExecuted(address(this), userAddresses[i], userDetail.depositAmount);
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
        emit TokenDistributed(address(this), userAddresses[i], userDetail.remainingAmount);

      }
      
      unchecked {
        i++;
      }
    }
  }

  //Withdraw remaining Stablecoin
  function withdrawStablecoin() external onlyTozex  {
    uint256 StablecoinBalance = usdcToken.balanceOf(address(this));
    usdcToken.safeTransfer(wallet, StablecoinBalance);
    emit WithdrawStablecoin(address(this), wallet, StablecoinBalance);
  }

  //Withdraw remaining Toz Token
  function withdrawToztoken() external onlyTozex  {
    uint256 TozTokenBalance = tozToken.balanceOf(address(this));
    tozToken.safeTransfer(wallet, TozTokenBalance);
    emit WithdrawToztoken(address(this), wallet, TozTokenBalance);
  }

  //Withdraw remaining token
  function withdrawtoken() external onlyTozex {
    uint256 TokenBalance = token.balanceOf(address(this));
    token.safeTransfer(wallet, TokenBalance);
    emit Withdrawtoken(address(this), wallet, TokenBalance);
  }

  // Calcul the amount of token the benifiaciary will get by buying during Sale
  function _getTokenAmount(TokenType _tt, uint256 _amount) internal view returns (uint256) {
    uint256 ratio = _tt == TokenType.TOZ ? tozRatio : usdcRatio;
    uint256 decimal = _tt == TokenType.TOZ ? 18 : usdcDecimal;

    uint256 _amountToSend = _amount.mul(ratio / 10000).mul(10 ** (tokenDecimal - decimal));
    return _amountToSend;
  }

  function _getNow() public virtual view returns (uint256) {
      return block.timestamp;
  }

}
