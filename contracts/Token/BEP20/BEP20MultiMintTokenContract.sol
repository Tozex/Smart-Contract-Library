pragma solidity ^0.8.1;

import "../../OpenZeppelin/Ownable.sol";
import "../../OpenZeppelin/SafeMath.sol";
import "./IBEP20.sol";

// SPDX-License-Identifier: GPL-3.0

/**
 * @dev Simple BEP20 Token example, with mintable token creation only during the deployement of the token contract */

contract BEP20MultiMintTokenContract is Ownable{
  using SafeMath for uint256;

  string public name;
  string public symbol;
  uint8 public decimals;
  uint256 public totalSupply;
  address public tokenOwner;
  address private ico;

  mapping(address => uint256) balances;
  mapping (address => mapping (address => uint256)) internal allowed;
  mapping(address => bool) public vestedlist;

  event SetICO(address indexed _ico);
  event Mint(address indexed to, uint256 amount);
  event MintFinished();
  event UnlockToken();
  event LockToken();
  event Burn();
  event Approval(address indexed owner, address indexed spender, uint256 value);
  event Transfer(address indexed from, address indexed to, uint256 value);
  event addedToVestedlist(address indexed _vestedAddress);
  event removedFromVestedlist(address indexed _vestedAddress);


  bool public mintingFinished = false;
  bool public locked = true;

  modifier canMint() {
    require(!mintingFinished);
    _;
  }

  modifier canTransfer() {
    require(!locked || msg.sender == owner || msg.sender == ico);
    _;
  }

  modifier onlyAuthorized() {
    require(msg.sender == owner || msg.sender == ico);
    _;
  }


  constructor(string memory _name, string memory  _symbol, uint8 _decimals) {
    require (_decimals != 0);
    name = _name;
    symbol = _symbol;
    decimals = _decimals;
    totalSupply = 0;
    balances[msg.sender] = totalSupply;
    emit Transfer(address(0), msg.sender, totalSupply);


  }

  /**
   * @dev Function to mint tokens
   * @param _to The address that will receive the minted tokens.
   * @param _amount The amount of tokens to mint.
   * @return A boolean that indicates if the operation was successful.
   */
  function mint(address _to, uint256 _amount) public onlyAuthorized canMint returns (bool) {
    totalSupply = totalSupply.add(_amount);
    balances[_to] = balances[_to].add(_amount);
    emit Mint(_to, _amount);
    emit Transfer(address(this), _to, _amount);
    return true;
  }

  /**
   * @dev Function to mint tokens
   * @param _tos The address that will receive the minted tokens.
   * @param _amounts The amount of tokens to mint.
   * @return A boolean that indicates if the operation was successful.
   */
  function mintMany(address[] calldata _tos, uint256[] calldata _amounts) public onlyAuthorized canMint returns (bool) {
    require(_tos.length == _amounts.length);
    for(uint256 i = 0; i < _tos.length; i ++) {
      totalSupply = totalSupply.add(_amounts[i]);
      balances[_tos[i]] = balances[_tos[i]].add(_amounts[i]);
      emit Mint(_tos[i], _amounts[i]);
      emit Transfer(address(this), _tos[i], _amounts[i]);
    }
    return true;
  }

  /**
   * @dev Function to stop minting new tokens.
   * @return True if the operation was successful.
   */
  function finishMinting() public onlyAuthorized canMint returns (bool) {
    mintingFinished = true;
    emit MintFinished();
    return true;
  }

  /**
  * @dev transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint256 _value) public canTransfer returns (bool) {
    require(_to != address(0));
	require (!isVestedlisted(msg.sender));
    require(_value <= balances[msg.sender]);
    require (msg.sender != address(this));

    // SafeMath.sub will throw if there is not enough balance.
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    emit Transfer(msg.sender, _to, _value);
    return true;
  }


  function burn(address _who, uint256 _value) onlyAuthorized public returns (bool){
    require(_who != address(0));

    totalSupply = totalSupply.sub(_value);
    balances[_who] = balances[_who].sub(_value);
    emit Burn();
    emit Transfer(_who, address(0), _value);
    return true;
  }

  function burnMany(address[] calldata _whos, uint256[] calldata _values) onlyAuthorized public returns (bool){
    require(_whos.length == _values.length);
    for(uint256 i = 0; i < _whos.length; i ++) {
      require(_whos[i] != address(0));

      totalSupply = totalSupply.sub(_values[i]);
      balances[_whos[i]] = balances[_whos[i]].sub(_values[i]);
      emit Burn();
      emit Transfer(_whos[i], address(0), _values[i]);
    }
    return true;
  }

  function balanceOf(address _owner) public view returns (uint256 balance) {
    return balances[_owner];
  }

  /**
   * @dev Transfer tokens from one address to another
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amount of tokens to be transferred
   */
  function transferFrom(address _from, address _to, uint256 _value) public canTransfer returns (bool) {
    require(_to != address(0));
    require (!isVestedlisted(msg.sender));
    require(_value <= balances[_from]);
    require(_value <= allowed[_from][msg.sender]);

    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    emit Transfer(_from, _to, _value);
    return true;
  }

  function transferFromBEP20Contract(address _to, uint256 _value) public onlyOwner returns (bool) {
    require(_to != address(0));
    require(_value <= balances[address(this)]);
    balances[address(this)] = balances[address(this)].sub(_value);
    balances[_to] = balances[_to].add(_value);
    emit Transfer(address(this), _to, _value);
    return true;
  }


  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   *
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   */
  function approve(address _spender, uint256 _value) public returns (bool) {
    require (!isVestedlisted(msg.sender));
    allowed[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);
    return true;
  }

  /**
   * @dev Function to check the amount of tokens that an owner allowed to a spender.
   * @param _owner address The address which owns the funds.
   * @param _spender address The address which will spend the funds.
   * @return A uint256 specifying the amount of tokens still available for the spender.
   */
  function allowance(address _owner, address _spender) public view returns (uint256) {
    return allowed[_owner][_spender];
  }

  /**
   * @dev Increase the amount of tokens that an owner allowed to a spender.
   *
   * approve should be called when allowed[_spender] == 0. To increment
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * @param _spender The address which will spend the funds.
   * @param _addedValue The amount of tokens to increase the allowance by.
   */
  function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
    allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  /**
   * @dev Decrease the amount of tokens that an owner allowed to a spender.
   *
   * approve should be called when allowed[_spender] == 0. To decrement
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * @param _spender The address which will spend the funds.
   * @param _subtractedValue The amount of tokens to decrease the allowance by.
   */
  function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
    uint oldValue = allowed[msg.sender][_spender];
    if (_subtractedValue > oldValue) {
      allowed[msg.sender][_spender] = 0;
    } else {
      allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
    }
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  function unlockToken() public onlyAuthorized returns (bool) {
    locked = false;
    emit UnlockToken();
    return true;
  }

  function lockToken() public onlyAuthorized returns (bool) {
    locked = true;
    emit LockToken();
    return true;
  }

  function setICO(address _icocontract) public onlyOwner returns (bool) {
    require(_icocontract != address(0));
    ico = _icocontract;
    emit SetICO(_icocontract);
    return true;
  }

    /**
     * @dev Adds list of addresses to Vestedlist. Not overloaded due to limitations with truffle testing.
     * @param _vestedAddress Addresses to be added to the Vestedlist
     */
    function addToVestedlist(address[] memory _vestedAddress) public onlyOwner {
        for (uint256 i = 0; i < _vestedAddress.length; i++) {
            if (vestedlist[_vestedAddress[i]]) continue;
            vestedlist[_vestedAddress[i]] = true;
        }
    }


    /**
     * @dev Removes single address from Vestedlist.
     * @param _vestedAddress Address to be removed to the Vestedlist
     */
    function removeFromVestedlist(address[] memory _vestedAddress) public onlyOwner {
        for (uint256 i = 0; i < _vestedAddress.length; i++) {
            if (!vestedlist[_vestedAddress[i]]) continue;
            vestedlist[_vestedAddress[i]] = false;
        }
    }

    function isVestedlisted(address _vestedAddress) internal view returns (bool) {
      return (vestedlist[_vestedAddress]);
    }


}
