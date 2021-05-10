pragma solidity ^0.8.1;

import "../lib/BEP20/BEP20TokenContract.sol";
import "../OpenZeppelin/SafeMath.sol";
import "../OpenZeppelin/PullPayment.sol";
import "../OpenZeppelin/Ownable.sol";

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

contract ICO is Ownable, PullPayment {

    using SafeMath for uint;

  // The token being sold
  BEP20TokenContract public token;

  // Decimals vlaue of the token
  uint256 TokenDecimals;

  // Address where funds are collected
  address payable public wallet;

  // Address to receive project tokens
  address public projectOwner;

  // Refund period if the ICO failed
  uint256 public refundPeriod;

  // How many token units a buyer gets per ETH/wei during Pre sale. The ETH price is returned by the ETH/USD chainlink price feed
  uint256 public Presalerate;

  // How many token units a buyer gets per ETH/wei during ICO. The ETH price is returned by the ETH/USD chainlink price feed
  uint256 public Icorate;

  // Amount of ETH/Wei raised during the ICO period
  uint256 public EthRaisedIco;

  // Amount of ETH/wei raised during the Pre sale
  uint256 public EthRaisedpresale;

  // Token amount distributed during the ICO period
  uint256 public tokenDistributed;

  // Token amount distributed during the Pre sale
  uint256 public tokenDistributedpresale;

  // investors part according to the whitepaper 60 % (50% ICO + 10% PreSale)
  uint256 public investors = 60;

  // Min purchase size of incoming ETH during pre sale period fixed at 2 ETH valued at 800 $
  uint256 public constant MIN_PURCHASE_Presale = 0.001 ether;

  // Minimum purchase size of incoming ETH during ICO at 1$
  uint256 public constant MIN_PURCHASE_ICO = 0.000025 ether;

  // Hardcap cap in Ether raised during Pre sale fixed at $ 200 000 for ETH valued at 440$
  uint256 public PresaleSalemaxCap1 = 1 ether;

  // Softcap funding goal during ICO in Ether raised fixed at $ 200 000 for ETH valued at 400$.
  uint256 public ICOminCap = 2 ether;

  // Hardcap goal in Ether during ICO in Ether raised fixed at $ 13 000 000 for ETH valued at 400$
  uint256 public ICOmaxCap = 32500 ether;

  // presale start/end
  bool public presale = true;    // State of the ongoing sales Pre sale

  // ICO start/end
  bool public ico = false;         // State of the ongoing sales ICO period

  // Balances in incoming Ether
  mapping(address => uint256) balances;

  // Bool to check that the Presalesale period is launch only one time
  bool public statepresale = false;

  // Bool to check that the ico is launch only one time
  bool public stateico = true;

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
   * @param _wallet Address where collected funds will be forwarded to
   * @param _token Address of the ERC20 Token
   * @param _TokenDecimals Decimals of the ERC20 Token
   * @param _project Address where the Token of the project will be sent
   */
  constructor(address payable _wallet, address _token, uint256 _TokenDecimals, address _project) {
    require(_wallet != address(0) && _token != address(0) && _project != address(0));
    wallet = _wallet;
    token = BEP20TokenContract(_token);
    projectOwner = _project;
    TokenDecimals = _TokenDecimals;
  }

  // -----------------------------------------
  // ICO external interface
  // -----------------------------------------

  /**
   * @dev fallback function ***DO NOT OVERRIDE***
   */
  receive() external payable {
    require(presale || ico , "Failed it was already closed");
     if (presale) {
      buypresaleTokens(msg.sender);
    }
    if (ico) {
      buyICOTokens(msg.sender);
    }
  }

  function buypresaleTokens (address _beneficiary) internal {
    require(_beneficiary != address(0) , "Failed the wallet is not allowed");
    require(msg.value >= MIN_PURCHASE_Presale, "Failed the amount is not respecting the minimum deposit of Presale ");
    // Check that if investors sends more than the MIN_PURCHASE_Presale
    uint256 weiAmount = msg.value;
	// According to the whitepaper the backers who invested on Presale Sale have not possibilities to be refunded. Their ETH Balance is updated to zero value.
	balances[msg.sender] = 0;
    // calculate token amount to be created
    uint256 tokensTocreate = _getTokenpresaleAmount(weiAmount);
    _getRemainingTokenStock(_beneficiary, tokensTocreate);
    emit TokenPurchase(msg.sender, _beneficiary, weiAmount, tokensTocreate);

    // update state
    EthRaisedpresale = EthRaisedpresale.add(weiAmount);
    tokenDistributedpresale = tokenDistributedpresale.add(tokensTocreate);

    // If Presale Sale softcap is reached then the ether on the ICO contract are send to project wallet
    if (EthRaisedpresale <= PresaleSalemaxCap1) {
      wallet.transfer(address(this).balance);
    } else {
      //If PresaleSalemaxCap1 is reached then the presale is closed
      if (EthRaisedpresale >= PresaleSalemaxCap1) {
        presale = false;
      }
    }
  }

  /**
   * @dev low level token purchase ***DO NOT OVERRIDE***
   * @param _beneficiary Address performing the token purchase
   */
  function buyICOTokens(address _beneficiary) internal {
	require(_beneficiary != address(0) , "Failed the wallet is not allowed");
    require(msg.value >= MIN_PURCHASE_ICO, "Failed the amount is not respecting the minimum deposit of ICO");
    // Check that if investors sends more than the MIN_PURCHASE_ICO
    uint256 weiAmount = msg.value;

    // calculate token amount to be created
    uint256 tokensTocreate = _getTokenAmount(weiAmount);

    // Look if there is token on the contract if he is not create the amount of token
    _getRemainingTokenStock(_beneficiary, tokensTocreate);
    emit TokenPurchase(msg.sender, _beneficiary, weiAmount, tokensTocreate);

    // update state
    EthRaisedIco = EthRaisedIco.add(weiAmount);

    // Creation of the token and transfer to beneficiary
    tokenDistributed = tokenDistributed.add(tokensTocreate);

    // Update the balance of benificiary
    balances[_beneficiary] = balances[_beneficiary].add(weiAmount);

    uint256 totalEthRaised = EthRaisedIco.add(EthRaisedpresale);

    // If ICOminCap is reached then the ether on the ICO contract are send to project wallet
    if (totalEthRaised >= ICOminCap && totalEthRaised <= ICOmaxCap) {
      wallet.transfer(address(this).balance);
    }

    //If ICOmaxCap is reached then the ICO close
    if (totalEthRaised >= ICOmaxCap) {
      ico = false;
    }
  }

  /* ADMINISTRATIVE FUNCTIONS */

  // Update the ETH ICO rate
  function updateETHIcoRate(uint256 _EtherAmount) public onlyOwner {
    Icorate = (_EtherAmount).mul(1 wei);
  }

    // Update the ETH PreSale rate
  function updateETHPresaleRate(uint256 _EtherAmount) public onlyOwner {
    Presalerate = (_EtherAmount).mul(1 wei);
  }

    // Update the ETH ICO MAX CAP
  function updateICOMaxcap(uint256 _EtherAmount) public onlyOwner {
    ICOmaxCap = (_EtherAmount).mul(1 wei);
  }

  // start presale
  function startpresale() public onlyOwner {
    require(statepresale && !ico,"Failed the Presale was already started or another sale is ongoing");
    presale = true;
    statepresale = false;
    token.lockToken();
  }

  // close Presale
  function closepresale() public onlyOwner {
    require(presale && !ico, "Failed it was already closed");
    presale = false;
  }

 // start ICO
  function startICO() public onlyOwner {

    // bool to see if the ico has already been launched and  presale is not in progress
    require(stateico && !presale, "Failed the ICO was already started or another salae is ongoing");

    ico = true;
    token.lockToken();

    // Put the bool to False to block the start of this function again
    stateico = false;
  }

  // close ICO
  function closeICO() public onlyOwner {
    require(!presale && ico,"Failed it was already closed");
    ico = false;
  }

  /* When ICO MIN_CAP is not reach the smart contract will be credited to make refund possible by backers
   * 1) backer call the "refund" function of the ICO contract
   * 2) backer call the "reimburse" function of the ICO contract to get a refund in ETH
   */
  function refund() public {
    require(_refundPeriod());
    require(balances[msg.sender] > 0);

    uint256 ethToSend = balances[msg.sender];
    balances[msg.sender] = 0;
    asyncSend(msg.sender, ethToSend);
  }

  function reimburse() public {
    require(_refundPeriod());
    withdrawPayments();
    EthRaisedIco = address(this).balance;
  }

  // Function to pay out if the ICO is successful
  function WithdrawFunds() public onlyOwner {
    require(!ico && !presale, "Failed a sales is ongoing");
    if (_isSuccessful()) {
      uint256 _tokensProjectToSend = _getTokenAmountToDistribute(100 - investors);
      _getRemainingTokenStock(projectOwner, _tokensProjectToSend);
      token.unlockToken();
    } else {
      wallet.transfer(address(this).balance);
    }

    // burn in case that there is some not distributed tokens on the contract
    if (token.balanceOf(address(this)) > 0) {
      uint256 totalDistributedToken = tokenDistributed;
      token.burn(address(this),totalDistributedToken);
    }
  }

  // -----------------------------------------
  // Internal interface (extensible)
  // -----------------------------------------

  /**
   * @dev Override to extend the way in which ether is converted to tokens.
   * @param _weiAmount Value in wei to be converted into tokens
   * @return Number of tokens that can be purchased with the specified _weiAmount
   */

  // Calcul the amount of token the benifiaciary will get by buying during Presale
  function _getTokenpresaleAmount(uint256 _weiAmount) internal view returns (uint256) {
    uint256 _amountToSend = _weiAmount.div(Presalerate).mul(10 ** TokenDecimals);
    return _amountToSend;
  }

  // Calcul the amount of token the benifiaciary will get by buying during Sale
  function _getTokenAmount(uint256 _weiAmount) internal view returns (uint256) {
    uint256 _amountToSend = _weiAmount.div(Icorate).mul(10 ** TokenDecimals);
    return _amountToSend;
  }

  // Calcul the token amount to distribute in the forwardFunds for the project (team, bounty ...)
  function _getTokenAmountToDistribute(uint _part) internal view returns (uint256) {
    uint256 _delivredTokens = tokenDistributed.add(tokenDistributedpresale);
    return (_part.mul(_delivredTokens).div(investors));

  }

  // verify the remaining token stock & deliver tokens to the beneficiary
  function _getRemainingTokenStock(address _beneficiary, uint256 _tokenAmount) internal {
    if (token.balanceOf(address(this)) >= _tokenAmount) {
      require(token.transfer(_beneficiary, _tokenAmount));
    }
    else {
      if (token.balanceOf(address(this)) == 0) {
        require(token.mint(_beneficiary, _tokenAmount));
      }
      else {
        uint256 remainingTokenTocreate = _tokenAmount.sub(token.balanceOf(address(this)));
        require(token.transfer(_beneficiary, token.balanceOf(address(this))));
        require(token.mint(_beneficiary, remainingTokenTocreate));
      }
    }
  }

  // Function to check the refund period
  function _refundPeriod() internal view returns (bool){
    require(!_isSuccessful(),"Failed refund period is not open");
    return (!ico && !stateico);
  }

  // check if the ico is successful
  function _isSuccessful() internal view returns (bool){
    return (EthRaisedIco.add(EthRaisedpresale) >= ICOminCap);
  }

}
