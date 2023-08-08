// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Multisignature wallet by TOZEX inspired by Gnosis Multisignature project for which we added new functionalities like transaction countdown validation and ERC20 tokens management.
/// @author Tozex company

import "../OpenZeppelin/SafeERC20.sol";
import "../OpenZeppelin/Ownable.sol";
import "../OpenZeppelin/IERC721Receiver.sol";
import "../OpenZeppelin/ERC1155Receiver.sol";
import "../Interface/IERC20.sol";
import "../Interface/IERC721.sol";
import "../Interface/IERC1155.sol";

contract MultiSigWallet is Ownable, IERC721Receiver, ERC1155Receiver {
  using SafeERC20 for IERC20;

  uint constant public MAX_OWNER_COUNT = 10;


  event Confirmation(address indexed sender, uint indexed transactionId);
  event Revocation(address indexed sender, uint indexed transactionId);
  event Submission(uint indexed transactionId);
  event Execution(uint indexed transactionId);
  event ExecutionFailure(uint indexed transactionId);
  event Deposit(address indexed sender, address indexed token, uint value);
  event ERC20Deposited(address indexed sender, address indexed token, uint value);
  event ERC721Deposited(address indexed sender, address indexed token, uint tokenId);
  event ERC1155Deposited(address indexed sender, address indexed token, uint tokenId, uint value);
  event SignerChangeRequested(address indexed currentSigner, address indexed newSigner);
  event SignerUpdated(address indexed oldSigner, address indexed newSigner);

  mapping(uint => Transaction) public transactions;
  mapping(uint => mapping(address => bool)) public confirmations;
  mapping(address => address) public signerChangeRequests;
  mapping(address => bool) public isSigner;
  address[] public signers;
  uint public required;
  uint public transactionCount;

  enum TokenStandard {
    ERC20,
    ERC721,
    ERC1155,
    USER
  }

  struct Transaction {
    address payable destination;
    address token;
    TokenStandard ts;
    uint tokenId;
    uint value;
    bytes data;
    bool executed;
    uint confirmTimestamp;
    uint txTimestamp;
  }

  
  
  modifier onlyWallet() {
    require(msg.sender == address(this));
    _;
  }

  modifier signerDoesNotExist(address signer) {
    require(!isSigner[signer]);
    _;
  }

  modifier signerExists(address signer) {
    require(isSigner[signer]);
    _;
  }

  modifier transactionExists(uint transactionId) {
    require(transactions[transactionId].destination != address(0));
    _;
  }

  modifier confirmed(uint transactionId, address signer) {
    require(confirmations[transactionId][signer]);
    _;
  }

  modifier notConfirmed(uint transactionId, address signer) {
    require(!confirmations[transactionId][signer], "Transaction already confirmed");
    _;
  }

  modifier notExecuted(uint transactionId) {
    require(!transactions[transactionId].executed);
    _;
  }

  modifier notNull(address _address) {
    require(_address != address(0));
    _;
  }

  modifier validRequirement(uint signerCount, uint _required) {
    require((signerCount <= MAX_OWNER_COUNT) || (required <= signerCount) || (_required != 0) || (signerCount != 0));
    _;
  }

  /** 
   * @dev Fallback function allows to deposit ether.
   */
  receive() external payable {
    if (msg.value > 0)
      emit Deposit(msg.sender, address(0), msg.value);
  }
  
  /**
   * Public functions
   * @dev Contract constructor sets initial signers and required number of confirmations.
   * @param _signers List of initial signers.
   * @param _required Number of required confirmations.
   */
  constructor (address[] memory _signers, uint _required) validRequirement(_signers.length, _required) {
    for (uint i = 0; i < _signers.length; i++) {
      require(!isSigner[_signers[i]] && _signers[i] != address(0) && _signers[i] != msg.sender);
      isSigner[_signers[i]] = true;
    }
    signers = _signers;
    required = _required;
  }

  /** 
   * @notice Allows the owner to request a change of signer.
   * @param _oldSigner The address of the current signer to be replaced.
   * @param _newSigner The address of the new signer to be added.
   */
  function requestSignerChange(address _oldSigner, address _newSigner) external onlyOwner {
    require(isSigner[_oldSigner], "Old signer does not exist.");
    require(!isSigner[_newSigner], "New signer is already a signer.");
    require(_newSigner != owner, "Onwer cannot be a signer.");

    signerChangeRequests[_oldSigner] = _newSigner;
    emit SignerChangeRequested(_oldSigner, _newSigner);
  }

  /**
   * @notice Allows a signer to confirm a signer change requested by the owner.
   * @param _oldSigner The address of the current signer to be replaced.
   * @param _newSigner The address of the new signer to be added.
   */
  function confirmSignerChange(address _oldSigner, address _newSigner) external signerExists(msg.sender) {
    require(signerChangeRequests[_oldSigner] == _newSigner, "New signer address invalid.");
    require(_newSigner != address(0), "No pending signer update request.");
    require(isSigner[_newSigner] == false, "New signer is already a signer.");

    // Confirm the update by the current signer
    signerChangeRequests[_oldSigner] = address(0);
    isSigner[_oldSigner] = false;
    isSigner[_newSigner] = true;
    signers.push(_newSigner);
    emit SignerUpdated(_oldSigner, _newSigner);
  }

  function depositERC20(address token, uint amount) external {
    require(token != address(0) , "invalid token");
    require(amount > 0 , "invalid amount");
    IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    emit ERC20Deposited(msg.sender, token, amount);
  }

  function depositERC721(address token, uint tokenId) external {
    require(IERC721(token).ownerOf(tokenId) == msg.sender, "You must own the ERC721 token.");
    // Transfer the ERC721 token to the multisig contract
    IERC721(token).safeTransferFrom(msg.sender, address(this), tokenId);
    emit ERC721Deposited(msg.sender, token, tokenId);
  }

  function depositERC1155(address token, uint tokenId, uint amount) external {
    require(IERC1155(token).balanceOf(msg.sender, tokenId) >= amount, "Insufficient ERC1155 balance.");
    // Transfer the ERC1155 tokens to the multisig contract
    IERC1155(token).safeTransferFrom(msg.sender, address(this), tokenId, amount, "");
    emit ERC1155Deposited(msg.sender, token, tokenId, amount);
  }

  /**
   * @dev Allows an signer to submit and confirm a transaction.
   * @param destination Transaction target address.
   * @param value Transaction ether value.
   * @param data Transaction data payload.
   */
  function submitTransaction(address payable destination, address token, TokenStandard ts, uint tokenId, uint value, bytes memory data, uint confirmTimestamp) public returns (uint transactionId) {
    uint txTimestamp = _getNow();
    transactionId = addTransaction(destination, token, ts, tokenId, value, data, confirmTimestamp, txTimestamp);
    confirmTransaction(transactionId);
  }
 
  /**
   * @dev Allows an signer to confirm a transaction.
   * @param transactionId Transaction ID.
   */
  function confirmTransaction(uint transactionId) public signerExists(msg.sender) transactionExists(transactionId) notConfirmed(transactionId, msg.sender) {
    require(_getNow() < transactions[transactionId].txTimestamp + transactions[transactionId].confirmTimestamp * 1 seconds || transactions[transactionId].confirmTimestamp == 0);
    confirmations[transactionId][msg.sender] = true;
    emit Confirmation(msg.sender, transactionId);
    executeTransaction(transactionId);
  }


  /**
   * @dev Allows anyone to execute a confirmed transaction.
   * @param transactionId Transaction ID.
   */
  function executeTransaction(uint transactionId) internal notExecuted(transactionId) {
    if (isConfirmed(transactionId)) {
      Transaction storage txn = transactions[transactionId];
      
      txn.executed = true;
      if(txn.ts == TokenStandard.USER) {
        require(address(this).balance >= txn.value, "not enough amount to withdraw");
        (bool transferSuccess,) =txn.destination.call{value: txn.value}(txn.data);
        if (transferSuccess)
          emit Execution(transactionId);
        else {
          emit ExecutionFailure(transactionId);
          txn.executed = false;
        }
      } else if(txn.ts == TokenStandard.ERC20) {
        require(IERC20(txn.token).balanceOf(address(this)) >= txn.value, "not enough amount to withdraw");
        IERC20(txn.token).safeTransfer(txn.destination, txn.value);
        emit Execution(transactionId);
      } else if(txn.ts == TokenStandard.ERC721) {
        require(IERC721(txn.token).ownerOf(txn.tokenId) == address(this), "not enough amount to withdraw");
        IERC721(txn.token).safeTransferFrom(address(this), txn.destination, txn.tokenId);
        emit Execution(transactionId);
      } else if(txn.ts == TokenStandard.ERC1155) {
        require(IERC1155(txn.token).balanceOf(address(this), txn.tokenId) >= txn.value, "not enough amount to withdraw");
        IERC1155(txn.token).safeTransferFrom(address(this), txn.destination, txn.tokenId, txn.value, "");
        emit Execution(transactionId);
      }
    }
  }
  
  /**
   * @dev Returns the confirmation status of a transaction.
   * @param transactionId Transaction ID.
   */
  function isConfirmed(uint transactionId) public view returns (bool) {
    uint count = 0;
    for (uint i = 0; i < signers.length; i++) {
      if (confirmations[transactionId][signers[i]])
        count += 1;
      if (count == required)
        return true;
    }
    return false;
  }

  /**
   * Internal functions
   *
   * @dev Adds a new transaction to the transaction mapping, if transaction does not exist yet.
   * @param destination Transaction target address.
   * @param value Transaction ether value.
   * @param data Transaction data payload.
   */
  function addTransaction(address payable destination, address token, TokenStandard ts, uint tokenId, uint value, bytes memory data, uint confirmTimestamp, uint txTimestamp) internal notNull(destination) returns (uint transactionId) {
    transactionId = transactionCount;
    transactions[transactionId] = Transaction({
      destination : destination,
      token: token,
      ts: ts,
      tokenId: tokenId,
      value : value,
      data : data,
      executed : false,
      confirmTimestamp : confirmTimestamp,
      txTimestamp : txTimestamp
      });
    transactionCount += 1;
    emit Submission(transactionId);
  }

  /**
   * Web3 call functions
   *
   * @dev Returns number of confirmations of a transaction.
   * @param transactionId Transaction ID.
   */
  function getConfirmationCount(uint transactionId) public view returns (uint count) {
    for (uint i = 0; i < signers.length; i++)
      if (confirmations[transactionId][signers[i]])
        count += 1;
  }

  /**
   * @dev Returns total number of transactions after filers are applied.
   * @param pending Include pending transactions.
   * @param executed Include executed transactions.
   */
  function getTransactionCount(bool pending, bool executed) public view returns (uint count) {
    for (uint i = 0; i < transactionCount; i++)
      if (pending && !transactions[i].executed || executed && transactions[i].executed)
        count += 1;
  }


  /**
   * @dev Returns array with signer addresses, which confirmed transaction.
   * @param transactionId Transaction ID.
   */
  function getConfirmations(uint transactionId) public view returns (address[] memory _confirmations) {
    address[] memory confirmationsTemp = new address[](signers.length);
    uint count = 0;
    uint i;
    for (i = 0; i < signers.length; i++)
      if (confirmations[transactionId][signers[i]]) {
        confirmationsTemp[count] = signers[i];
        count += 1;
      }
    _confirmations = new address[](count);
    for (i = 0; i < count; i++)
      _confirmations[i] = confirmationsTemp[i];
  }

  /**
   * @dev Returns list of transaction IDs in defined range.
   * @param from Index start position of transaction array.
   * @param to Index end position of transaction array.
   * @param pending Include pending transactions.
   * @param executed Include executed transactions.
   */
  function getTransactionIds(uint from, uint to, bool pending, bool executed) public view returns (uint[] memory _transactionIds)
  {
    uint[] memory transactionIdsTemp = new uint[](transactionCount);
    uint count = 0;
    uint i;
    for (i = 0; i < transactionCount; i++)
      if (pending && !transactions[i].executed
      || executed && transactions[i].executed)
      {
        transactionIdsTemp[count] = i;
        count += 1;
      }
    _transactionIds = new uint[](to - from);
    for (i = from; i < to; i++)
      _transactionIds[i - from] = transactionIdsTemp[i];
  }

  function _getNow() internal view returns (uint256) {
      return block.timestamp;
  }

  /**
    * @dev See {IERC721Receiver-onERC721Received}.
    *
    * Always returns `IERC721Receiver.onERC721Received.selector`.
    */
  function onERC721Received(
      address,
      address,
      uint256,
      bytes memory
  ) public virtual override returns (bytes4) {
      return this.onERC721Received.selector;
  }

  function onERC1155Received(
      address,
      address,
      uint256,
      uint256,
      bytes memory
  ) public virtual override returns (bytes4) {
      return this.onERC1155Received.selector;
  }

  function onERC1155BatchReceived(
      address,
      address,
      uint256[] memory,
      uint256[] memory,
      bytes memory
  ) public virtual override returns (bytes4) {
      return this.onERC1155BatchReceived.selector;
  }
}
