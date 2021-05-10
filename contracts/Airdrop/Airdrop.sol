pragma solidity ^0.4.24;

import "./Ownable.sol";
import "./ERC20.sol";
import "./SafeMath.sol";
//@title- ICO token application
//@owner- Tozex.io

contract Airdrop is Ownable {
    using SafeMath for uint256;

    struct Investor {
        uint256 amountLeft;
        bool locked;
    }

    ERC20 public token;

    mapping (address => bool) public whitelist;
    mapping (address => Investor) public investorDetails;

    event LogWhitelisted(address _address, uint256 _amount);
    event LogClaim(address _address, uint256 _amount);

    modifier isWhitelisted() {
        require(whitelist[msg.sender] == true, "Investor is not whitelisted");
        _;
    }


    /**
     * @dev constructor is getting tokens from the token contract
     * @param _token Address of the token
     */
    constructor(address _token) public {
        token = ERC20(_token);
    }


    /**
       * Rejecting direct ETH payment to the contract
       */
    function() external {
        revert();
    }

    function addWhitelist(address[] calldata _investors, uint256[] calldata _amounts) external onlyOwner {
        require(_investors.length == _amounts.length, "Input array 's length mismatch");

        for (uint i = 0; i < _investors.length; i++) {
            whitelist[_investors[i]] = true;
            investorDetails[_investors[i]] = Investor(_amounts[i], false);

            emit LogWhitelisted(_investors[i], _amounts[i]);
        }
    }

    function claim() public isWhitelisted {
        require(investorDetails[msg.sender].locked == false, "Investor locked");

        uint256 amount = investorDetails[msg.sender].amountLeft;
        investorDetails[msg.sender] = Investor(0, true);

        token.transfer(msg.sender, amount * 10**18);

        emit LogWhitelisted(msg.sender, amount * 10**18);
    }

    function setTokenAddress(address _token) public onlyOwner {
        require(_token != address(0));
        token = ERC20(_token);
    }

    /**
     * @dev This function is used to sort the array of address and token to send tokens
     * @param _investorsAdd Address array of the investors
     * @param _tokenVal Array of the tokens
     * @return tokens Calling function to send the tokens
     */

    function airdropTokenDistributionToAll(address[] memory _investorsAdd, uint256[] memory _tokenVal) public onlyOwner  returns (bool success){
        require(_investorsAdd.length == _tokenVal.length, "Input array's length mismatch");
        for(uint i = 0; i < _investorsAdd.length; i++ ){
            require(airdropTokenDistributionOnebyOne(_investorsAdd[i], _tokenVal[i]));
        }
        return true;
    }

    /**
     * @dev This function is used to get token balance at addresses from the array
     * @param _investorsAdd Array if address of the investors
     * @param _tokenVal Array of tokens to be send
     * @return bal Balance
     */

    function airdropTokenDistributionOnebyOne(address _investorsAdd, uint256 _tokenVal) public onlyOwner returns (bool success){
        require(_investorsAdd != owner, "Receiver is not the owner of the contract");
        require(token.transfer(_investorsAdd, _tokenVal));
        return true;
    }

    /**
     * @dev This function is used to add remaining token balance to the owner address
     * @param _tokenAddress Address of the token contract
     * @return true
     */

    function withdrawTokenBalance(address _tokenAddress) public onlyOwner returns (bool success){
        require(token.transfer(_tokenAddress, token.balanceOf(address(this))));
        return true;
    }
}