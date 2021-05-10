pragma solidity ^0.8.1;

import "../Token/ERC20/MintableToken.sol";
import "../OpenZeppelin/SafeMath.sol";
import "../OpenZeppelin/PullPayment.sol";
import "../OpenZeppelin/Pausable.sol";
import "../OpenZeppelin/Whitelist.sol";

// SPDX-License-Identifier: GPL-3.0

/**
 * @title Crowdsale
 * @dev Crowdsale is a base contract for managing a token crowdsale,
 * allowing investors to purchase tokens with ether. This contract implements
 * such functionality in its most fundamental form and can be extended to provide additional
 * functionality and/or custom behavior.
 * The external interface represents the basic interface for purchasing tokens, and conform
 * the base architecture for crowdsales. They are *not* intended to be modified / overriden.
 * The internal interface conforms the extensible and modifiable surface of crowdsales. Override
 * the methods to add functionality. Consider using 'super' where appropiate to concatenate
 * behavior.
 */

contract Crowdsale is Pausable, PullPayment, Whitelist {

  using SafeMath for uint256;

  // The token being sold
  MintableToken public token;

  // Address where funds are collected
  address public wallet;

  // Address to receive project tokens
  address public projectOwner;

  // How many token units a buyer gets per wei
  uint256 public rate;

  // Amount of wei raised during the crowdsale period
  uint256 public weiRaised;

  // Amount of wei raised during the presale period
  uint256 public weiRaisedPresale;

  // Token amount distributed during the crowdsale period
  uint256 public tokenDistributed;

  // Token amount distributed during the presale period
  uint256 public tokenDistributedPresale;

  // investors part
  uint256 public investors;

  // Minimum purchase size of incoming ETH
  uint256 public constant MIN_PURCHASE = 0.05 ether;

  // Maximum goal in Ether raised
  uint256 public maxCap;

  // Minimum funding goal in Ether raised
  uint256 public minCap;

  // ICO start/end
  bool public crowdsale = false;

  // Presale start/end
  bool public presale = false;

  // Presale discount
  uint public presaleDiscount;

  // Refund period
  uint256 public refundPeriod;

  // KYC value
  uint public kycLimit;

  // First discount round
  uint public firstDiscoundCap;

  // Second discount round
  uint public secondDiscoundCap;

  // First Cap discount
  uint public discountcap;

  // Balances in incoming Ether
  mapping(address => uint256) balances;

  // Bool to check that the presale is launch only one time
  bool public statepresale = true;

  // Bool to check that the crowdsale is launch only one time
  bool public statecrowdsale = true;

  // TozexLiquidityReserve address
  address public TozexLiquidityReserve = 0x8667D6122408028d913Ce2143e0910143207BD1a ;

  /**
   * Event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   */
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
  event NewContract(address indexed _from, address indexed _contract, string _type);
  /**
   * @param _rate Number of token units a buyer gets per wei
   * @param _wallet Address where collected funds will be forwarded to
   */
  constructor(uint _rate, address _wallet, address _token, uint _minCap, uint _maxCap, uint _investors, address _project,
    uint _firstDiscoundCap, uint _secondDiscoundCap, uint _discountcap, uint _presaleDiscount, uint _kycLimit) public payable {

    require(_wallet != address(0) && _token != address(0) && _project != address(0));
    require(_rate != 0 && _minCap != 0 && _maxCap != 0 && _investors != 0 && _firstDiscoundCap != 0 && _secondDiscoundCap != 0
    && _discountcap != 0 && _presaleDiscount != 0 && _kycLimit != 0);

    rate = _rate;
    wallet = _wallet;
    token = MintableToken(_token);
    minCap = _minCap.mul(1 ether);
    maxCap = _maxCap.mul(1 ether);
    investors = _investors;
    projectOwner = _project;
    firstDiscoundCap = _firstDiscoundCap;
    secondDiscoundCap = _secondDiscoundCap;
    kycLimit = _kycLimit.mul(1 ether);
    discountcap = _discountcap.mul(1 ether);
    presaleDiscount = _presaleDiscount;


    emit NewContract(owner, this, "Crowdsale");
  }

  // -----------------------------------------
  // Crowdsale external interface
  // -----------------------------------------

  /**
   * @dev fallback function ***DO NOT OVERRIDE***
   */
  function() external payable whenNotPaused {
    require(presale || crowdsale);
    if (presale) {
      buyPresaleTokens(msg.sender);
    }

    if (crowdsale) {
      buyTokens(msg.sender);
    }
  }

  /**
   * @dev low level token purchase ***DO NOT OVERRIDE***
   * @param _beneficiary Address performing the token purchase
   */
  function buyTokens(address _beneficiary) internal {

    uint256 weiAmount = msg.value;
    _preValidatePurchase(_beneficiary, weiAmount);

    // calculate token amount to be created
    uint256 tokensTocreate = _getTokenAmount(weiAmount);

    // Look if there is token on the contract if he is not create the amount of token
    _getRemainingTokenStock(_beneficiary, tokensTocreate);
    emit TokenPurchase(msg.sender, _beneficiary, weiAmount, tokensTocreate);

    // update state
    weiRaised = weiRaised.add(weiAmount);

    // Creation of the token and transfer to beneficiary
    tokenDistributed = tokenDistributed.add(tokensTocreate);

    // Update the balance of benificiary
    balances[_beneficiary] = balances[_beneficiary].add(weiAmount);

    uint256 totalWeiRaised = weiRaised.add(weiRaisedPresale);

    // If minCap is reached then the ether on the ICO contract are send to project wallet
    if (totalWeiRaised >= minCap && totalWeiRaised <= maxCap) {
      TozexLiquidityReserve.transfer(address(this).balance.mul(5).div(100));
      wallet.transfer(address(this).balance);
    }

    //If maxCap is reached then the crowdsale close
    if (totalWeiRaised >= maxCap) {
      crowdsale = false;
    }
  }


  function buyPresaleTokens(address _beneficiary) internal {
    uint256 weiAmount = msg.value;
    _preValidatePurchase(_beneficiary, weiAmount);

    // calculate token amount to be created
    uint256 tokensTocreate = _getTokenPresaleAmount(weiAmount);

    _getRemainingTokenStock(_beneficiary, tokensTocreate);
    emit TokenPurchase(msg.sender, _beneficiary, weiAmount, tokensTocreate);

    // update state
    weiRaisedPresale = weiRaisedPresale.add(weiAmount);
    tokenDistributedPresale = tokenDistributedPresale.add(tokensTocreate);

    // If minCap is reached then the ether on the ICO contract are send to project wallet
    if (weiRaisedPresale >= minCap && weiRaisedPresale <= maxCap) {
      TozexLiquidityReserve.transfer(address(this).balance.mul(5).div(100));
      wallet.transfer(address(this).balance);
    } else {
      //If maxCap is reached then the presale close
      if (weiRaisedPresale >= maxCap) {
        presale = false;
      }
    }
  }

  // start ICO
  function startCrowdsale() public onlyOwner {

    // bool to see if the crowdsale has already been launched
    require(statecrowdsale);

    // Presale is not in progress
    require(!presale);

    // Check if presale has been launched
    if (!statepresale) {
      // require than the time set in the presale is not reached
      require(now < refundPeriod);

      // add 30 day to the to li of the ICO
      refundPeriod = now.add(2592000);
      // 30 days in seconds ==> 30*24*3600

      // if Presale has not been launched
    } else {
      refundPeriod = now.add(7776000);
      // 90 days in seconds ==> 3*30*24*3600
    }

    // check if the maxCap is not reached
    require(weiRaisedPresale < maxCap);
    crowdsale = true;
    token.lockToken();

    // Put the bool to False to block the start of this function again
    statecrowdsale = false;
  }

  // close ICO
  function closeCrowdsale() public onlyOwner {
    require(!presale && crowdsale);
    crowdsale = false;
  }

  // start presale
  function startPresale() public onlyOwner {
    require(statepresale);
    presale = true;
    statepresale = false;
    refundPeriod = now.add(7776000);
    // 90 days in seconds ==> 3*30*24*360
    token.lockToken();
  }

  // close ICO
  function closePresale() public onlyOwner {
    require(presale && !crowdsale);
    presale = false;
  }

  /* When MIN_CAP is not reach the smart contract will be credited to make refund possible by backers
   * 1) backer call the "refund" function of the Crowdsale contract
   * 2) backer call the "withdrawPayments" function of the Crowdsale contract to get a refund in ETH
   */
  function refund() public {
    require(_refundPeriod());
    require(balances[msg.sender] > 0);

    uint256 ethToSend = balances[msg.sender];
    balances[msg.sender] = 0;
    asyncSend(msg.sender, ethToSend);
  }

  function withdraw() public {
    require(_refundPeriod());
    withdrawPayments();
    weiRaised = address(this).balance;
  }

  // Function to pay outs
  function forwardFunds() public onlyOwner {
    require(!crowdsale && !presale);
    require(now > refundPeriod.add(7776000) || _isSuccessful());
    //  90 days in seconds ==> 2*30*24*3600
    if (_isSuccessful()) {
      uint256 _tokensProjectToSend = _getTokenAmountToDistribute(100 - investors);
      uint256 TozexLiquiditypart = _getTokenAmountToDistribute(100 - investors).mul(5).div(100);
      _getRemainingTokenStock(projectOwner, _tokensProjectToSend.sub(TozexLiquiditypart));
      _getRemainingTokenStock(TozexLiquidityReserve, TozexLiquiditypart);
      token.unlockToken();
    } else {
      wallet.transfer(weiRaised);
    }

    // burn
    if (token.balanceOf(this) > 0) {
      uint256 totalDistributedToken = tokenDistributed.add(tokenDistributedPresale);
      token.burn(totalDistributedToken);
    }
  }


  // -----------------------------------------
  // Internal interface (extensible)
  // -----------------------------------------

  /**
   * @dev Validation of an incoming purchase. Use require statemens to revert state when conditions are not met. Use super to concatenate validations.
   * @param _beneficiary Address performing the token purchase
   * @param _weiAmount Value in wei involved in the purchase
   */
  function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) internal {

    require(_beneficiary != address(0));
    // Check that the address of the benifiaciary is different of nothing
    require(_weiAmount >= MIN_PURCHASE);
    // Check that he sends more than the MIN_PURCHASE

    if (_weiAmount > kycLimit) {// if he sends more than the kycLimit he need to be Whitelist
      require(isWhitelisted(_beneficiary));
    }
  }
  /**
   * @dev Override to extend the way in which ether is converted to tokens.
   * @param _weiAmount Value in wei to be converted into tokens
   * @return Number of tokens that can be purchased with the specified _weiAmount
   */

  // Calcul the amount of token the benifiaciary will get by buying during Presale
  function _getTokenPresaleAmount(uint256 _weiAmount) internal view returns (uint256) {
    uint256 _amount = _weiAmount.mul(rate);
    uint256 _amountToSend = (presaleDiscount.mul(_amount)).div(100);
    return _amount.add(_amountToSend);
  }

  // Calcul the amount of token the benifiaciary will get by buying during Sale
  function _getTokenAmount(uint256 _weiAmount) internal view returns (uint256) {
    uint256 _amount = _weiAmount.mul(rate);
    return _amount.add(_getBonus(_amount));
  }

  // Calcul the token amount to distribute in the forwardFunds
  function _getTokenAmountToDistribute(uint _part) internal view returns (uint256) {
    uint256 _delivredTokens = tokenDistributed.add(tokenDistributedPresale);
    return (_part.mul(_delivredTokens).div(investors));

  }

  // verify the remaining token stock & deliver tokens to the beneficiary
  function _getRemainingTokenStock(address _beneficiary, uint256 _tokenAmount) internal {
    if (token.balanceOf(this) >= _tokenAmount) {
      require(token.transfer(_beneficiary, _tokenAmount));
    }
    else {
      if (token.balanceOf(this) == 0) {
        require(token.mint(_beneficiary, _tokenAmount));
      }
      else {
        uint256 remainingTokenTocreate = _tokenAmount.sub(token.balanceOf(this));
        require(token.transfer(_beneficiary, token.balanceOf(this)));
        require(token.mint(_beneficiary, remainingTokenTocreate));
      }
    }
  }

  // Function to check the refund period
  function _refundPeriod() internal view returns (bool){
    require(!_isSuccessful());
    return ((!crowdsale && !presale && !statecrowdsale) || (now > refundPeriod));
  }

  // Token bonus calculated on the initial investment amount
  function _getBonus(uint256 _weiAmount) internal view returns (uint256){
    uint256 bonus = 0;

    if (_weiAmount <= discountcap.mul(rate)) {
      bonus = (_weiAmount.mul(firstDiscoundCap)).div(100);
    }
    else {
      bonus = (_weiAmount.mul(secondDiscoundCap)).div(100);
    }
    return bonus;
  }

  // check if the crowdsale is successful
  function _isSuccessful() internal view returns (bool){
    return (weiRaised.add(weiRaisedPresale) >= minCap);
  }
}
