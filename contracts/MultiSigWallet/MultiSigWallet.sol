pragma solidity ^0.4.24;

/// @title Multisignature wallet by TOZEX inspired by Gnosis Multisignature project fir which we added new functionalities like transaction countdown validation .
/// @author Tozex company

contract MultiSigWallet {
  uint constant public MAX_OWNER_COUNT = 10;


  event Confirmation(address indexed sender, uint indexed transactionId);
  event Revocation(address indexed sender, uint indexed transactionId);
  event Submission(uint indexed transactionId);
  event Execution(uint indexed transactionId);
  event ExecutionFailure(uint indexed transactionId);
  event Deposit(address indexed sender, uint value);


  mapping(uint => Transaction) public transactions;
  mapping(uint => mapping(address => bool)) public confirmations;
  mapping(address => bool) public isOwner;
  address[] public owners;
  uint public required;
  uint public transactionCount;


  struct Transaction {
    address destination;
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

  modifier ownerDoesNotExist(address owner) {
    require(!isOwner[owner]);
    _;
  }

  modifier ownerExists(address owner) {
    require(isOwner[owner]);
    _;
  }

  modifier transactionExists(uint transactionId) {
    require(transactions[transactionId].destination != 0);
    _;
  }

  modifier confirmed(uint transactionId, address owner) {
    require(confirmations[transactionId][owner]);
    _;
  }

  modifier notConfirmed(uint transactionId, address owner) {
    require(!confirmations[transactionId][owner]);
    _;
  }

  modifier notExecuted(uint transactionId) {
    require(!transactions[transactionId].executed);
    _;
  }

  modifier notNull(address _address) {
    require(_address != 0);
    _;
  }

  modifier validRequirement(uint ownerCount, uint _required) {
    require((ownerCount <= MAX_OWNER_COUNT) || (required <= ownerCount) || (_required != 0) || (ownerCount != 0));
    _;
  }

  /// @dev Fallback function allows to deposit ether.
  function() payable public {
    if (msg.value > 0)
      emit Deposit(msg.sender, msg.value);
  }

  /*
   * Public functions
   */
  /// @dev Contract constructor sets initial owners and required number of confirmations.
  /// @param _owners List of initial owners.
  /// @param _required Number of required confirmations.
  constructor (address[] _owners, uint _required) public validRequirement(_owners.length, _required) {
    for (uint i = 0; i < _owners.length; i++) {
      require(isOwner[_owners[i]] || _owners[i] != 0);
      isOwner[_owners[i]] = true;
    }
    owners = _owners;
    required = _required;


  }


  /// @dev Allows an owner to submit and confirm a transaction.
  /// @param destination Transaction target address.
  /// @param value Transaction ether value.
  /// @param data Transaction data payload.
  /// @return Returns transaction ID.
  function submitTransaction(address destination, uint value, bytes data, uint confirmTimestamp) public returns (uint transactionId) {
    uint txTimestamp = now;
    transactionId = addTransaction(destination, value, data, confirmTimestamp, txTimestamp);
    confirmTransaction(transactionId);
  }

  /// @dev Allows an owner to confirm a transaction.
  /// @param transactionId Transaction ID.
  function confirmTransaction(uint transactionId) public ownerExists(msg.sender) transactionExists(transactionId) notConfirmed(transactionId, msg.sender) {
    require(now < transactions[transactionId].txTimestamp + transactions[transactionId].confirmTimestamp * 1 seconds || transactions[transactionId].confirmTimestamp == 0);
    confirmations[transactionId][msg.sender] = true;
    emit Confirmation(msg.sender, transactionId);
    executeTransaction(transactionId);
  }



  /// @dev Allows anyone to execute a confirmed transaction.
  /// @param transactionId Transaction ID.
  function executeTransaction(uint transactionId) internal notExecuted(transactionId) {
    if (isConfirmed(transactionId)) {
      Transaction storage txn = transactions[transactionId];
      txn.executed = true;
      if (txn.destination.call.value(txn.value)(txn.data))
        emit Execution(transactionId);
      else {
        emit ExecutionFailure(transactionId);
        txn.executed = false;
      }
    }
  }

  /// @dev Returns the confirmation status of a transaction.
  /// @param transactionId Transaction ID.
  /// @return Confirmation status.
  function isConfirmed(uint transactionId) public constant returns (bool) {
    uint count = 0;
    for (uint i = 0; i < owners.length; i++) {
      if (confirmations[transactionId][owners[i]])
        count += 1;
      if (count == required)
        return true;
    }
  }

  /*
   * Internal functions
   */
  /// @dev Adds a new transaction to the transaction mapping, if transaction does not exist yet.
  /// @param destination Transaction target address.
  /// @param value Transaction ether value.
  /// @param data Transaction data payload.
  /// @return Returns transaction ID.
  function addTransaction(address destination, uint value, bytes data, uint confirmTimestamp, uint txTimestamp) internal notNull(destination) returns (uint transactionId) {
    transactionId = transactionCount;
    transactions[transactionId] = Transaction({
      destination : destination,
      value : value,
      data : data,
      executed : false,
      confirmTimestamp : confirmTimestamp,
      txTimestamp : txTimestamp
      });
    transactionCount += 1;
    emit Submission(transactionId);
  }


  /*
   * Web3 call functions
   */
  /// @dev Returns number of confirmations of a transaction.
  /// @param transactionId Transaction ID.
  /// @return Number of confirmations.
  function getConfirmationCount(uint transactionId) public constant returns (uint count) {
    for (uint i = 0; i < owners.length; i++)
      if (confirmations[transactionId][owners[i]])
        count += 1;
  }

  /// @dev Returns total number of transactions after filers are applied.
  /// @param pending Include pending transactions.
  /// @param executed Include executed transactions.
  /// @return Total number of transactions after filters are applied.
  function getTransactionCount(bool pending, bool executed) public constant returns (uint count) {
    for (uint i = 0; i < transactionCount; i++)
      if (pending && !transactions[i].executed || executed && transactions[i].executed)
        count += 1;
  }

  /// @dev Returns array with owner addresses, which confirmed transaction.
  /// @param transactionId Transaction ID.
  /// @return Returns array of owner addresses.
  function getConfirmations(uint transactionId) public constant returns (address[] _confirmations) {
    address[] memory confirmationsTemp = new address[](owners.length);
    uint count = 0;
    uint i;
    for (i = 0; i < owners.length; i++)
      if (confirmations[transactionId][owners[i]]) {
        confirmationsTemp[count] = owners[i];
        count += 1;
      }
    _confirmations = new address[](count);
    for (i = 0; i < count; i++)
      _confirmations[i] = confirmationsTemp[i];
  }

  /// @dev Returns list of transaction IDs in defined range.
  /// @param from Index start position of transaction array.
  /// @param to Index end position of transaction array.
  /// @param pending Include pending transactions.
  /// @param executed Include executed transactions.
  /// @return Returns array of transaction IDs.
  function getTransactionIds(uint from, uint to, bool pending, bool executed) public constant returns (uint[] _transactionIds)
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

}
