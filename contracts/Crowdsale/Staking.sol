pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract Staking is Ownable, Pausable{
    
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    event SetFee(
        uint256 fee
    );

    event SetDevWallet(
        address devWallet
    );

    event SetToken(
        address token
    );

    event SetMonthlyInterest(
        uint256 monthlyInterest
    );

    event SetQuarterlyInterest(
        uint256 quarterlyInterest
    );
    
    event Deposit(
        address user, 
        uint256 amount,
        bool isMonthly
    );
    
    event WithdrawToken(
        address user, 
        uint256 amount
    );

    struct UserDetail {
        uint256 depositTime;
        uint256 depositAmount;
        uint256 lastActionTime;
        bool isMonthly;
    }

    IERC20 token;

    mapping(address => UserDetail[]) public userDetail;

    uint256 public constant month = 30 days;
    uint256 public constant quarter = 90 days;

    uint256 public monthlyInterest = 20; // 2%
    uint256 public quarterlyInterest = 100; // 10%
    uint256 public fee = 10; // 1%
    address public devWallet;

    constructor(IERC20 _token, address _devWallet) {
        require(address(_token) != address(0));
        require(_devWallet != address(0));
        token = _token;
        devWallet = _devWallet;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
        emit SetFee(_fee);
    }

    function setDevWallet(address _devWallet) external onlyOwner {
        devWallet = _devWallet;
        emit SetDevWallet(_devWallet);
    }

    function setToken(IERC20 _token) external onlyOwner {
        require(address(_token) != address(0));
        token = _token;
        emit SetToken(address(_token));
    }

    function setMonthlyInterest(uint256 _monthlyInterest) external onlyOwner {
        monthlyInterest = _monthlyInterest;
        emit SetMonthlyInterest(_monthlyInterest);
    }

    function setQuarterlyInterest(uint256 _quarterlyInterest) external onlyOwner {
        quarterlyInterest = _quarterlyInterest;
        emit SetQuarterlyInterest(_quarterlyInterest);
    }

    function getReward(address _user) public view returns (uint256, uint256) {
        UserDetail[] storage user = userDetail[_user];

        uint256 monthlyReward;
        uint256 quarterlyReward;

        for (uint256 i = 0; i < user.length; i ++) {
            if(_getNow() > user[i].depositTime) {
                uint256 periodPassed = timePassed(user[i].depositTime, _getNow(), user[i].isMonthly) - timePassed(user[i].depositTime, user[i].lastActionTime, user[i].isMonthly);
                if(user[i].isMonthly) {
                    monthlyReward = monthlyReward.add(getRewardMonthly(user[i].depositAmount, periodPassed));
                }
                else {
                    quarterlyReward = quarterlyReward.add(getRewardQuarterly(user[i].depositAmount, periodPassed));
                }
            }
        }
        return (monthlyReward, quarterlyReward);
    }

    function getDeposit(address _user) public view returns (uint256, uint256) {
        UserDetail[] storage user = userDetail[_user];

        uint256 monthlyDeposit;
        uint256 quarterlyDeposit;

        for (uint256 i = 0; i < user.length; i ++) {
            if(user[i].isMonthly) {
                monthlyDeposit = monthlyDeposit.add(user[i].depositAmount);
            }
            else {
                quarterlyDeposit = quarterlyDeposit.add(user[i].depositAmount);
            }
        }
        return (monthlyDeposit, quarterlyDeposit);
    }

    function deposit(address _user, uint256 _amount, bool _isMonthly) public whenNotPaused {

        require(_user != address(0), "Staking.deposit: Deposit user address should not be zero address");

        uint256 oldBalance = token.balanceOf(address(this));
        token.transferFrom(msg.sender, address(this), _amount);
        uint256 newBalance = token.balanceOf(address(this));
        _amount = newBalance.sub(oldBalance);

        UserDetail[] storage user = userDetail[_user];
        UserDetail memory userInfo;

        userInfo.depositTime = _getNow();
        userInfo.depositAmount = _amount;
        userInfo.lastActionTime = _getNow();
        userInfo.isMonthly = _isMonthly;
        user.push(userInfo);

        emit Deposit(_user, _amount, _isMonthly);
    }
    
    function withdraw(uint256 _amount) public whenNotPaused {
        (uint256 monthlyReward, uint256 quarterlyReward) = getReward(msg.sender);
        uint256 unlocked = getUnlockedDeposit(msg.sender);

        require(unlocked >= _amount, "Not enough tokens to withdraw");

        //Claiming Reward
        uint256 rewardAmount = monthlyReward.add(quarterlyReward);
        UserDetail[] storage user = userDetail[msg.sender];
        if(rewardAmount > 0) {
            for (uint256 i = 0; i < user.length; i ++) {
                user[i].lastActionTime = _getNow();
            }
            token.safeTransfer(msg.sender, rewardAmount);
        }

        if(_amount > 0) {
            withdrawByElement(msg.sender, _amount);
            
            uint256 feeAmount = _amount.mul(fee).div(1e3);
            uint256 transferAmount = _amount.sub(feeAmount);
            token.safeTransfer(devWallet, feeAmount);
            token.safeTransfer(msg.sender, transferAmount);
        }
        
        emit WithdrawToken(msg.sender, _amount);
    }

    function removeDepositedElement(address _user , uint _index) internal {
        UserDetail[] storage user = userDetail[_user];

        require(_index < user.length, "xCrssToken: Index of user detail array out of bound");

        for (uint i = _index ; i < user.length - 1; i++) {
            user[i] = user[i + 1];
        }
        user.pop();
    }
    
    function timePassed(uint256 _prevTime, uint256 _currentTime, bool _isMonthly) internal pure returns(uint256) {
        uint256 passedTime = _currentTime.sub(_prevTime);
        uint256 passed;
        if(_isMonthly) {
            passed = passedTime.div(month);
        }
        else {
            passed = passedTime.div(quarter);
        }
        return passed;
    }

    
    function getUnlockedDeposit(address _user) internal view returns (uint256) {
        UserDetail[] storage user = userDetail[_user];
        uint256 unlocked;
        for (uint256 i = 0; i < user.length; i ++) {
            if(_getNow() > user[i].depositTime) {
                uint256 periodPassed = timePassed(user[i].depositTime, _getNow(), user[i].isMonthly);

                if(periodPassed >= 1){
                    unlocked = unlocked.add(user[i].depositAmount);
                }
            }
        }
        return unlocked;
    }

    function withdrawByElement(address _user, uint256 _withdrawAmount) internal {
        UserDetail[] storage user = userDetail[_user];

        for (uint256 i = 0; i < user.length; i ++) {
            if(_getNow() > user[i].depositTime) {
                if(_withdrawAmount > 0) {
                    uint256 periodPassed = timePassed(user[i].depositTime, _getNow(), user[i].isMonthly);

                    if(periodPassed >= 1){
                        if (user[i].depositAmount >= _withdrawAmount) {
                            user[i].depositAmount = user[i].depositAmount.sub(_withdrawAmount);
                            user[i].lastActionTime = _getNow();
                            _withdrawAmount = 0;
                        } else {
                            _withdrawAmount = _withdrawAmount.sub(user[i].depositAmount);
                            user[i].depositAmount = 0;
                            user[i].lastActionTime = _getNow();
                        }
                    }
                }
            }
        }

        for (uint256 i = 0 ; i < user.length ; i ++) {
            if (user[i].depositAmount == 0) {
                removeDepositedElement(_user, i);
            }
        }
    }

    function _getNow() public virtual view returns (uint256) {
        return block.timestamp;
    }

    function getRewardMonthly(uint256 _amount, uint256 _month) internal view returns(uint256) {
        if(_month == 0) {
            return 0;
        }
        else if(_month == 1) {
            return _amount.mul(monthlyInterest).div(1e3);
        }
        else {
            return _amount.add(getRewardMonthly(_amount, _month - 1)).mul(monthlyInterest).div(1e3);
        }
    }

    function getRewardQuarterly(uint256 _amount, uint256 _quarter) internal view returns(uint256) {
        if(_quarter == 0) {
            return 0;     
        }
        else if(_quarter == 1) {
            return _amount.mul(quarterlyInterest).div(1e3);
        }
        else {
            return _amount.add(getRewardQuarterly(_amount, _quarter - 1)).mul(quarterlyInterest).div(1e3);
        }
    }
}