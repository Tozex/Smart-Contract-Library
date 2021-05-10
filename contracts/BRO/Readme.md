# Believers Reward Offering contract

The BRO contract is to get funds from investors and giving them repayments and reimbursements with stablecoins
and TOZ token.
It will conduct the BRO campaign and control whitelisting, campaign lifecycle, 
redistribute bonuses and claim rewards etc.

### Variable

| Variable | Type | Description |
| ------ | ------ | ------ |
| tusdToken | public ERC20 | Address of TUSD token contract.
| daiToken | public ERC20 | Address of DAI token contract.
| usdtToken | public ERC20 | Address of USDT token contract.
| tozToken | public MintableToken | Address of TOZ token contract.
| broStartTimestamp | public uint | Timestamp for BRO campaign start
| broDuration | public uint | duration of BRO campaign
| broState | BroState | status flag of current BRO stage
| masterWallet | private address payable | master withdraw wallet address
| believersArray | private address[] payable | list of address of investors
| loanConfigs | mapping (uint8 => LoanConfig) | Configuration for BRO campaign, i.e. repayment, reimbursement rate for each quarter, duration etc
| believers | mapping (address => Believer) | investor database with information for loan amount, loan start time, duration, last quarter etc.
| rewardPlans | (address => RewardPlan) | database for staking bonus amount for each quarter
| whitelist | mapping (address => bool) | database for whitelisted investors
| bonusTozBalances | mapping (address => uint) | bonus amount for each investor



#### Constructor
The constructor initializes stablecoin contract instances, and set stablecoin address, and initializes loan settings.

#### Function

##### Function payable()

This function used to deny direct ether transaction to BRO smart contract

##### Function depositLoan()

This function is to let investors to pay (deposit) stablecoins to the BRO contract and register their loan.
This function pulls out stablecoin from the investors wallet address so the investor should `approve` the invest amount
before calling this function.
After pulling the stablecoins from investor's wallet, one half will be sent to master wallet address and another half will be remaining in the BRO
contract for repayment in the first quarter.
Also this function registers the BRO investment and calculates repayment/reimbursement/staking bonus amounts for each quarter.


##### Function payout()

This function will be used to distribute repayments and reimbursements in stablecoin/TOZ token for each quarter dates.
It's decentralized function, anyone whitelisted can call this function but the repayment/reimbursement will be valid to process one a quarter.

##### Function claimStakingBonus()

This function is used for believers to claim their long term staking bonus amounts.
Repayments/reimbursement of interests will be distributed quarterly by the above `payout` function but staking bonus will be held by BRO contract.
Believers can withdraw the bonus TOZ tokens any time by this function.

##### Function getLendersCount()

This function returns total count of loan investors

##### Function getLoanData()

This function returns detailed loan information for specific investor.

##### Function getRewardPlan()

This function returns repayment/reimbursement amounts for each quarter

##### Function getLoanConfig()

This function returns loan setting for each quarter such as min/max amount for the quarter, interest rate, quarter count etc

##### Function addToWhitelist()

This function is used to whitelist bulk investors at a time.

##### Function removeFromWhitelist()

This function is used to remove bulk investors from whitelist at a time.

#### Administrative Functions

##### Function startBRO()

This function is to start BRO campaign.

##### Function pauseBRO()

This function is to pause BRO campaign.

##### Function finishBRO()

This function is to complete BRO campaign.

##### Function updateMasterWallet()

This function is to update new master wallet

##### Function updateStableCoins()

This function is to update stablecoin contract addresses

##### Function withdraw()

This function is used to withdraw stablecoins in emergency case to prevent lose

#### Internal Functions

##### Function sendStableCoin()

This function is used to send stablecoins to destination address

##### Function mintToz()

This function is used to mint TOZ token to destination address

##### Function getLoanTire()

This function is decide loan tier for certain investment amount

##### Function initLoanConfig()

This function is initialize loan settings
