// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;
interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}
contract BridgeAssistB {
    address public owner;
    IERC20 public TKN;

    modifier restricted {
        require(msg.sender == owner, "This function is restricted to owner");
        _;
    }
    modifier notNull(address _address) {
        require(_address != address(0));
        _;
    }

    modifier transactionExists(uint transactionId) {
        require(transactions[transactionId].destination != address(0));
        _;
    }

    modifier notExecuted(uint transactionId) {
        require(!transactions[transactionId].executed);
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

    event Collect(address indexed sender, uint256 amount);
    event Dispense(address indexed sender, uint256 amount);
    event TransferOwnership(address indexed previousOwner, address indexed newOwner);
    event Submission(uint indexed transactionId);
    event Execution(uint indexed transactionId);
    event Confirmation(address indexed sender, uint indexed transactionId);

    struct Transaction {
        address payable destination;
        address token;
        uint code;
        uint value;
        bytes data;
        bool executed;
        uint confirmTimestamp;
        uint txTimestamp;
    }
    
    uint public constant COLLECT_CODE = 1;
    uint public constant DISPENSE_CODE = 2;
    uint public transactionCount;

    address public dev;

    mapping(uint => Transaction) public transactions;
    mapping(uint => mapping(address => bool)) public confirmations;

    constructor(address _dev) {
        dev = _dev;
        owner = msg.sender;

    }
    
    function submitTransaction(address payable destination, address token, uint code, uint value, bytes memory data, uint confirmTimestamp) public returns (uint transactionId) {
        uint txTimestamp = _getNow();
        transactionId = addTransaction(destination, token, code, value, data, confirmTimestamp, txTimestamp);
        confirmTransaction(transactionId);
    }

    function addTransaction(address payable destination, address token, uint code, uint value, bytes memory data, uint confirmTimestamp, uint txTimestamp) internal notNull(destination) returns (uint transactionId) {
        transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            destination : destination,
            token: token,
            code: code,
            value : value,
            data : data,
            executed : false,
            confirmTimestamp : confirmTimestamp,
            txTimestamp : txTimestamp
        });
        transactionCount += 1;
        emit Submission(transactionId);
    }

    function isConfirmed(uint transactionId) public returns (bool) {
        uint count = 0;
        address user = transactions[transactionId].destination;
        if (confirmations[transactionId][user] || confirmations[transactionId][dev])
            return true;
        else
            return false;
    }
    
    function confirmTransaction(uint transactionId) public transactionExists(transactionId) notConfirmed(transactionId, msg.sender) {
        require(_getNow() < transactions[transactionId].txTimestamp + transactions[transactionId].confirmTimestamp * 1 seconds || transactions[transactionId].confirmTimestamp == 0);
        require(msg.sender == dev || msg.sender == transactions[transactionId].destination, "doesnt have a role to confirm");

        confirmations[transactionId][msg.sender] = true;
        emit Confirmation(msg.sender, transactionId);
        executeTransaction(transactionId);
    }


    function executeTransaction(uint transactionId) internal notExecuted(transactionId) returns (bool) {
        if (isConfirmed(transactionId)) {
            Transaction storage txn = transactions[transactionId];
            txn.executed = true;
            if(txn.code == COLLECT_CODE) {
                IERC20(txn.token).transferFrom(txn.destination, address(this), txn.value);
                emit Collect(txn.destination, txn.value);
            } else {
                IERC20(txn.token).transfer(txn.destination, txn.value);
                emit Dispense(txn.destination, txn.value);
            }
            return true;
        }
        return false;
    }

    function transferOwnership(address _newOwner) external restricted {
        require(_newOwner != address(0), "Invalid address: should not be 0x0");
        emit TransferOwnership(owner, _newOwner);
        owner = _newOwner;
    }

    function _getNow() internal view returns (uint256) {
      return block.timestamp;
    }

}