pragma solidity ^0.5.10;

import "./lib/Ownable.sol";
import "../Token/ERC20/ERC20.sol";
import "./lib/SafeMath.sol";
import "../Token/ERC20/MintableToken.sol";
import "./lib/Address.sol";

interface IUSDT {
    function balanceOf(address who) external returns (uint);
    function transfer(address _to, uint _value) external;
    function transferFrom(address _from, address _to, uint _value) external;
}

/**
 * @title Belivers Reward Offering
 * @author Tozex
 */
contract BRO is Ownable {
    using SafeMath for uint;
    using Address for address;

    struct Believer {
        address stableCoin;
        uint fundDate;
        uint loanStartDate;
        uint loanEndDate;
        uint loanAmount;
        uint8 tier;
        uint8 lastQuarter;
        bool claimedStakingBonus;
        bool finishedPayout;
    }

    struct LoanConfig {
        uint16 min;
        uint24 max;
        uint8 quarterCount;
        uint8 interestRate;
        uint8 duration;
    }

    struct RewardPlan {
        uint repaymentUsdAmount;
        uint qRepaymentTozAmount;
        uint qInterestAmount;
        mapping (uint8 => uint) stakingBonuses;
    }

    enum BroState {PREPARE, RUNNING, PAUSED, FINISHED, REFUNDING}

    // define constants for DAI/TUSD stable coins
    address public TUSD_ADDRESS;
    address public DAI_ADDRESS;
    address public USDT_ADDRESS;

    // define constants fro day/quarter days
    uint public constant QUARTER_DAYS = 90 days;
    uint public constant ONE_DAY = 1 days;

    // define DAI/TUSD/USDT token contract instances
    ERC20 public tusdToken;
    ERC20 public daiToken;
    IUSDT public usdtToken;
    MintableToken public tozToken;

    // Timestamps for BRO campaign
    uint public broStartTimestamp;
    uint public broDuration;

    // BRO state variables
    BroState public broState = BroState.PREPARE;

    // define master wallet address
    address payable private masterWallet;
    address payable[] private believersArray;

    // mapping for believers database
    mapping (uint8 => LoanConfig) public loanConfigs;
    mapping (address => Believer) public believers;
    mapping (address => RewardPlan) public rewardPlans;
    mapping (address => bool) private whitelist;
    mapping (address => uint) private bonusTozBalances;

    // BRO events definition
    event StartBRO();
    event PauseBRO();
    event FinishBRO();
    event TransferEnabled();
    event PaybackStableCoin(address indexed _token, address indexed _to, uint indexed _amount);
    event PaybackToz(address indexed _to, uint indexed _amount);
    event AddWhitelist(address indexed _address);
    event RemoveFromWhitelist(address indexed _address);
    event UpdateMaserWallet(address payable _masterWallet);
    event UpdateStableCoins();
    event DepositLoan(address indexed _lender, uint _amount, address _coin);
    event ClaimStakingBonus(address indexed _lender, uint _amount);
    event Withdraw(uint _tusdAmount, uint _daiAmount, uint _usdtAmount);

    /**
     * @dev check only supported stablecoins
     */
    modifier isAcceptableTokens(address _token) {
        require(_token == TUSD_ADDRESS || _token == DAI_ADDRESS || _token == USDT_ADDRESS, "Unsupported Token");
        _;
    }

    /**
     * @dev check only whitelisted lenders
     */
    modifier isWhitelisted(address _address) {
        require(whitelist[_address], "Address is not whitelisted");
        _;
    }

    /**
     * @param _tozToken address Contract address of TOZ token
     * @param _masterWallet address Address of masterWallet
     * @param _broDuration uint Duration of BRO campaign in days
     * @param _tusdToken address Address of TUSD token
     * @param _daiToken address Address of DAI stablecoin
     * @param _usdtToken address Address of USDT stablecoin
     */
    constructor(address _tozToken, address payable _masterWallet, uint _broDuration, address _tusdToken, address _daiToken, address _usdtToken) public {
        require(_masterWallet != address(0));
        masterWallet = _masterWallet;
        broDuration = _broDuration * ONE_DAY;

        // initialize TOZ token instance
        tozToken = MintableToken(_tozToken);
        daiToken = ERC20(_daiToken);
        tusdToken = ERC20(_tusdToken);
        usdtToken = IUSDT(_usdtToken);

        // set token addresses
        TUSD_ADDRESS = _tusdToken;
        DAI_ADDRESS = _daiToken;
        USDT_ADDRESS = _usdtToken;

        // initialize configuration
        initLoanConfig();
    }

    /**
     * Rejecting direct ETH payment to the contract
     */
    function() external {
        revert();
    }

    /**
     * @dev Function to deposit stable coin. This will be called from loan investors directly
     *
     * @param _token address Contract address of stable coin
     * @param _amount uint Amount of deposit
     *
     * @notice Investor should call approve() function of token contract before calling this function
     */
    function depositLoan(address _token, uint _amount) public isAcceptableTokens(_token) returns (bool) {
        require(broState == BroState.RUNNING, "BRO is not active");

        // only accept only once
        require(believers[msg.sender].loanAmount == 0, "Deposit is allowed only once");

        // validate _amount between min/max
        require(_amount >= 10 && _amount <=100000, "Invalid amount");

        // move half of stable coin to masterWallet
        if (_token == USDT_ADDRESS) {
            IUSDT token = IUSDT(_token);

            // send half amount to master wallet
            token.transferFrom(msg.sender, masterWallet, _amount.mul(10**6).div(2));
            // send half amount to BRO contract for repayment
            token.transferFrom(msg.sender, address(this), _amount.mul(10**6).div(2));
        } else {
            ERC20 token = ERC20(_token);

            // send half amount to master wallet
            require(token.transferFrom(msg.sender, masterWallet, _amount.mul(10**18).div(2)), "Failed transferFrom to masterWallet");
            // send half amount to BRO contract for repayment
            require(token.transferFrom(msg.sender, address(this), _amount.mul(10**18).div(2)), "Failed transferFrom to BRO");
        }

        // register the loan amount
        uint8 tier = getLoanTire(_amount);
        uint8 quarterCount = loanConfigs[tier].quarterCount;

        believers[msg.sender] = Believer(
            _token,
            now,
            now + broDuration,
            now + broDuration + loanConfigs[tier].duration * 30 * ONE_DAY,
            _amount,
            tier,
            0,
            false,
            false
        );

        believersArray.push(msg.sender);

        // calculating reward plan
        uint interestRate = loanConfigs[tier].interestRate;
        uint quarterCapitalReimbursed = _amount.div(2 * quarterCount);
        uint quarterInterests = _amount.mul(interestRate).div(100).div(quarterCount);

        RewardPlan storage rewardPlan = rewardPlans[msg.sender];
        rewardPlan.repaymentUsdAmount = _amount.div(2);
        rewardPlan.qRepaymentTozAmount = quarterCapitalReimbursed;
        rewardPlan.qInterestAmount = quarterInterests;

        // calculate staking bonus for each quarter (Maximum iteration is 6)
        uint sum = 0;
        uint8 q = 1;
        uint bonus = 0;
        while(q <= quarterCount) {
            rewardPlan.stakingBonuses[q] = bonus;
            sum += quarterCapitalReimbursed.add(quarterInterests).add(bonus);
            bonus = sum.div(10);
            q++;
        }

        emit DepositLoan(msg.sender, _amount, address(_token));
        return true;
    }

    /**
     * @dev Function to pay back and distribute rewards quarterly
     *
     * @notice this function should be called periodically, quarterly basis to distribute
     * reimbursements, interest of loan, excluding bonus for long term staking
     */
    function payout() public isWhitelisted(msg.sender) {
        // check if the BRO is finished
        require(broState == BroState.FINISHED, "BRO is not finished yet");

        // iterate all believers
        for (uint8 i = 0; i < believersArray.length; i++) {
            Believer memory lender = believers[believersArray[i]];
            RewardPlan memory rewardPlan = rewardPlans[believersArray[i]];

            // exclude if payout is finished for each lender
            if (lender.finishedPayout) continue;

            // escape if one quarter is not elapsed from last quarter
            uint expectedQuarterlyDate = lender.loanStartDate + (lender.lastQuarter + 1) * QUARTER_DAYS;
            if (now < expectedQuarterlyDate) continue;

            // reimburse as USD for first quarter only
            if (lender.lastQuarter == 0 && rewardPlan.repaymentUsdAmount > 0) {
                // reset the repayment for USD
                rewardPlans[believersArray[i]].repaymentUsdAmount = 0;

                // send DAI/TUSD
                sendStableCoin(lender.stableCoin, believersArray[i], rewardPlan.repaymentUsdAmount);
            }

            if (rewardPlan.qRepaymentTozAmount == 0) continue;

            // summarize
            believers[believersArray[i]].lastQuarter = believers[believersArray[i]].lastQuarter + 1;

            // mint TOZ reimburseAmount (reimburseAmount + interestTozAmount) excluding staking bonus
            mintToz(believersArray[i], rewardPlan.qRepaymentTozAmount.add(rewardPlan.qInterestAmount));

            if (believers[believersArray[i]].lastQuarter == loanConfigs[lender.tier].quarterCount) {
                believers[believersArray[i]].finishedPayout = true;
                // reset TOZ repayment amount
                rewardPlans[believersArray[i]].qRepaymentTozAmount = 0;
                rewardPlans[believersArray[i]].qInterestAmount = 0;
            }
        }
    }

    /**
     * @dev Withdraw believers staking bonus
     */
    function claimStakingBonus() public isWhitelisted(msg.sender) returns (uint) {
        // check if the BRO is finished
        require(broState == BroState.FINISHED, "BRO is not finished yet");
        // should not claim bonus before
        require(believers[msg.sender].claimedStakingBonus == false, "Msg.sender already claimed his bonus");

        Believer memory lender = believers[msg.sender];
        RewardPlan storage rewardPlan = rewardPlans[msg.sender];

        uint totalBonus = 0;
        uint remainingBonus = 0;
        uint8 quarterCount = loanConfigs[lender.tier].quarterCount;
        uint lastQuarter = now.sub(lender.loanStartDate).div(QUARTER_DAYS);

        for (uint8 q = 1; q <= lastQuarter; q++) {
            totalBonus = totalBonus.add(rewardPlan.stakingBonuses[q]);
            // empty staking bonus amount
            rewardPlans[msg.sender].stakingBonuses[q] = 0;
        }

        for (uint8 q = quarterCount; q > lastQuarter; q--) {
            remainingBonus = remainingBonus.add(rewardPlan.stakingBonuses[q]);
            // empty staking bonus amount
            rewardPlans[msg.sender].stakingBonuses[q] = 0;
        }

        // claimedStakingBonus true (reentrancy prevent)
        believers[msg.sender].claimedStakingBonus = true;

        // mint token
        mintToz(msg.sender, totalBonus);

        // mint remaining bonus to master wwallet
        mintToz(masterWallet, remainingBonus);

        emit ClaimStakingBonus(msg.sender, totalBonus);
        return totalBonus;
    }

    /**
     * @dev Function to get lenders count
     */
    function getLendersCount() public view returns (uint) {
        return believersArray.length;
    }

    /**
     * @dev Function to read loan information
     */
    function getLoanData(address _lender) public view returns (address, uint, uint, uint8, uint8, bool, bool) {
        return (believers[_lender].stableCoin, believers[_lender].loanAmount, believers[_lender].loanStartDate, believers[_lender].tier, believers[_lender].lastQuarter, believers[_lender].claimedStakingBonus, believers[_lender].finishedPayout);
    }

    /**
     * @dev Function to read reward plan
     */
    function getRewardPlan(address _lender) public view returns (uint, uint, uint) {
        return (rewardPlans[_lender].repaymentUsdAmount, rewardPlans[_lender].qRepaymentTozAmount, rewardPlans[_lender].qInterestAmount);
    }

    /**
     * @dev Function to get staking bonus for a specific quarter
     */
    function getRewardPlan(address _lender, uint8 _quarter) public view returns (uint) {
        return rewardPlans[_lender].stakingBonuses[_quarter];
    }

    /**
     * @dev Function to get lenders count
     */
    function getLoanConfig(uint8 _quarter) public view returns (uint8, uint8, uint8) {
        return (loanConfigs[_quarter].quarterCount, loanConfigs[_quarter].interestRate, loanConfigs[_quarter].duration);
    }

    /**
     * @dev Function to add whitelist
     */
    function addToWhitelist(address[] memory _addresses) public onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            if (whitelist[_addresses[i]]) continue;
            whitelist[_addresses[i]] = true;
        }
    }

    /**
     * @dev Function to remove from whitelist
     */
    function removeFromWhitelist(address[] memory _addresses) public onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            if (!whitelist[_addresses[i]]) continue;
            whitelist[_addresses[i]] = false;
        }
    }

    // -------------- Administrative functions -------------- //
    /**
     * @dev Function to start BRO campaign
     */
    function startBRO() public onlyOwner returns (bool) {
        broState = BroState.RUNNING;

        broStartTimestamp = now;

        emit StartBRO();
        return true;
    }

    /**
     * @dev Function to pause BRO campaign
     */
    function pauseBRO() public onlyOwner returns (bool) {
        broState = BroState.PAUSED;

        emit PauseBRO();
        return true;
    }

    /**
     * @dev Function to finish BRO campaign
     */
    function finishBRO() public onlyOwner returns (bool) {
        broState = BroState.FINISHED;

        emit FinishBRO();
        return true;
    }

    /**
     * @dev Function to replace TOZEX multisig wallet address
     */
    function updateMasterWallet(address payable _masterWallet) public onlyOwner {
        require(_masterWallet != address(0));
        masterWallet = _masterWallet;

        emit UpdateMaserWallet(_masterWallet);
    }

    /**
     * @dev Function to update Stablecoin addresses for TUSD/DAI
     */
    function updateStableCoins(address _tusdToken, address _daiToken, address _usdtToken) public onlyOwner {
        require(_tusdToken.isContract());
        require(_daiToken.isContract());
        require(_usdtToken.isContract());

        daiToken = ERC20(_daiToken);
        tusdToken = ERC20(_tusdToken);
        usdtToken = IUSDT(_usdtToken);

        // set token addresses
        TUSD_ADDRESS = _tusdToken;
        DAI_ADDRESS = _daiToken;
        USDT_ADDRESS = _usdtToken;

        emit UpdateStableCoins();
    }

    /**
     * @dev Withdraw TUSD/DAI/USDT to master wallet for security
     */
    function withdraw() public onlyOwner {
        require(broState == BroState.FINISHED);

        uint tusdBalance = tusdToken.balanceOf(address(this));
        uint daiBalance = daiToken.balanceOf(address(this));
        uint usdtBalance = usdtToken.balanceOf(address(this));

        if (tusdBalance > 0) {
            tusdToken.transfer(masterWallet, tusdBalance);
        }

        if (daiBalance > 0) {
            daiToken.transfer(masterWallet, daiBalance);
        }

        if (usdtBalance > 0) {
            usdtToken.transfer(masterWallet, usdtBalance);
        }

        emit Withdraw(tusdBalance, daiBalance, usdtBalance);
    }

    // -------------- Internal functions -------------- //

    /**
     * @dev Send TUSD/DAI/USDT to lender for reimbursement
     * @notice this should be discussed
     */
    function sendStableCoin(address _token, address payable _receiver, uint _amount) internal isAcceptableTokens(_token) returns (uint) {
        if (_token == USDT_ADDRESS) {
            IUSDT token = IUSDT(_token);

            token.transfer(_receiver, _amount.mul(10**6));
        } else {
            ERC20 token = ERC20(_token);

            require(token.transfer(_receiver, _amount.mul(10**18)), "Failed transfering stablecoin");
        }

        emit PaybackStableCoin(_token, _receiver, _amount);
        return _amount;
    }

    /**
     * @dev Mint TOZ to lender for reimbursement and reward
     */
    function mintToz(address _receiver, uint _amount) internal returns (uint) {
        uint weiAmount = _amount.mul(10**18);

        // send TOZ token
        require(tozToken.mint(_receiver, weiAmount), "Failed minting TOZ");

        emit PaybackToz(_receiver, _amount);
        return _amount;
    }

    /**
     * @dev Get proper tier for the loan amount
     */
    function getLoanTire(uint _amount) internal pure returns (uint8 tier) {
        if (_amount >= 10 && _amount <= 10000) {
            tier = 1;
        } else if (_amount > 10000 && _amount <= 50000) {
            tier = 2;
        } else if (_amount > 50000 && _amount <= 100000) {
            tier = 3;
        }
    }

    /**
     * @dev Initialize loan configuration for each tier 1, 2, 3
     */
    function initLoanConfig() internal {
        loanConfigs[1] = LoanConfig(10, 10000, 4, 10, 12);
        loanConfigs[2] = LoanConfig(10001, 50000, 5, 12, 15);
        loanConfigs[3] = LoanConfig(50001, 100000, 6, 15, 18);
    }
}

