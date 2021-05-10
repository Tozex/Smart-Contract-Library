pragma solidity ^0.4.24;

contract Traceability{
  mapping(address => string) public contracts;   // mapping type of deployed contracts
  address[] public deployed;   // store deployed contracts

  function addContract(address _contract, string _type) public {
    contracts[_contract]= _type;
    deployed.push(_contract);
  }

  function getContracts() view public returns(address[]) {
    return deployed;
  }
}
