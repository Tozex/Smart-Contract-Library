# Crowdfunding Contract (ICO)

Deploying a crowdfunding tradable token contract with a set of hard coded parameters allows to ensure that all conditions of the launched crowdfunding campaign will be completely trustless and transparent : amount to raise (min & max cap), bonus (pre sale, crowdsale), KYC (limit amount, Whitelist), Refund period, wallet addresses (project (team, founders, partners ...) and investors).

Moreover the crowdsale contract requieres the ownership of the ERC20 contract managing the entire process to distribute and create tokens following the crowdfunding set up rules. 

More information : https://medium.com/tozex/tozex-smart-contract-library-6aaca54ca871

### Variables

| Variable name | Type | Description |
| ------ | ------ | ------ |
| Wallet | address public | Ethereum project wallet where the fund will go if the crowdsale is successfull |
| Project Owner | address public  | Ethereum  wallet where the token for the project will be send if the crowdsale is successful
| Rate | uint256 | The Token/ETH conversion rate representing the number of token a contributor will get per ETH
| WeiRaised | uint256 | Amount of ETH raised during the ICO period
| WeiRaisedPresale | uint256 | Amount of ETH raised during the presale period
| Token Distributed | uint256 | Amount of Token ditributed during the ICO period
| Token DistributedPresale | uint256 | Amount of Token distributed during the presale period
| Investors| uint256 | The percentage of token dedicated to investors (Pre sale + ICO)
| MIN_PURCHASE | uint256 constant| The minimum of ETH a contributor can send to buy during the sales
| maxCap | uint256 | The maximum amount of ETH neccessary to close the fundraising 
| minCap | uint256 | The minimun amount of ETH necessary to make the fundraising successful
| crowdsale | bool | Boolean to check the state of the ICO phase 
| presale | bool | Boolean to check the state of the presale 
| presaleDiscount | uint256 | Token discount that the contributor will get during the presale
| refundPeriod | uint256 | Refund period when the refund is allowed 
| kycLimit | uint256 | Maximum of ETH you can invest without doing the kyc
| Discountcap | uint256 | The Max Bonus threshold reprsenting the minimum amount of investement a contributor has to send to get Max bonus calculate by secondDiscountCap
| firstDiscountCap | uint256 | Percentage of token "Min Bonus" bonus the contributor will get during ICO by investing under the Discountcap
| secondDiscountCap | uint256 | Percentage of token "Max Bonus" the contributor will get during ICO by investing an amount equal or more than the Discountcap.
| balances | mapping (address --> uint256) | The amount of ETH the contract hanlde
| statepresale | bool | State of presale (running or close) 
| statecrowdsale | bool | State of the ICO (running or close)
| token | MintableToken public | Variable set to use function on MintableToken.sol

### Constructor

Variables filled in the constructor are done during the creation of the contract. 

### Function

##### Function () payable external 

This function allowed contributor to send ether during the presale or the crowdsale period only. And of course when the contract is not paused. 

##### Function buyTokens ()
If a contributor send ehter durinng the crowdsale period then the function buytoken is called. This function check if some prevalidate parameters are respected precise in the function _prevalidatePurchase, then it calculates the amount of token that will be sent to the contributor. The function check if there is enought token on the contract and how many need to be created for the contributor. In case the minCap has been reached then the funds are sent to the project wallet. Otherwise it will stay on the crowdsale contract until it will be refunded to contributors.

##### Function buyPresaleTokens ()
The same thing of the previous function but for presale period. This means the bonus is different and depends of the variable "presaleDiscount".

##### Function startCrowdsale ()

This function allows the owner of the contract to start the crowdsale period. If a presale has been launched previously then a period of 30 days is added to the refundperiod time. If there is no pre sale a period of 90 days will be added to the refundperiod time. 

##### Function closeCrowdsale ()

Function used to close the crowdsale period when the refundperiod was not reached.

##### Function startPresale ()

This function allows to launch the presale period. When executed it will add 90 days to refund period time.

##### Function closeCrowdsale ()

Function used to close the presale period.

##### Function _prevalidatePurchase()

This function is called by buyTokens() and buyPresaleTokens() and checks if the contributor is sending more that the MIN_PURCHASE and if he is sending more than the kyc limit by checking the whitelisted wallets.

##### Function _getTokenPresaleAmount()

This function is called by buyPresaleTokens() and calculate the amount of discount with the variable "presaleDiscount" for the contributor during the presale period.

##### Function _getTokenAmount()

This function is called by buyTokens() and calculate the investor discount amount during the crowdsale period with the variable "firstDiscountCap" or "secondDiscountCap".

##### Function _getTokenAmountToDistribute()

This function is called by forwardfunds() if the crowdsale contract is successful. It's calculating the part of token reserved for the team. 

##### Function _getRemainingTokenStock()

This function is called by buyTokens(), buyPresaleTokens() and forwardfunds(). It's checking the amount of token on the contract to send it to the contributor or the team after the calculation repartition. In the case there is not enought token the function mint new tokens to reach the amount needed.

##### Function _refundPeriod()

This function checks the refund period state of the crowdsale contract.

##### Function _getBonus()

This function calculate the bonus of token the contributor will get during the crowdsale period. If the contributor is investing more than the "Discountcap" variable he will have a bigger bonus defined by the secondDiscountCap variale.

##### Function _isSuccessful()

This function checks the successful state of the crowdsale.

##### Function refund ()

In the case the crowdsale contract failed and the minCap has not been reached the contributor can get back his investment by calling the function withdraw () . The function check how much the contributor invest and calculate this amount.

##### Function withdraw ()

When a contributor want to be refunded he has to call the refund function to calculate the amount of ether he invested to get back his initial investment.

##### Function forwardFunds() 

This function is called at the end of the crowdsale contract. In the case the crowdsale is successful this function call a function to calculate the part of the team and send it to the project owner. Then the token transfer capability is unlocked allowing contributors to use their token. In the case the crowdsale contract failed this function otherwise it's stay locked for the contributor to get back their investments during the refund period. If at the end of the refundPeriod some beneficiaries didn't refunded the remaining token will be send to the project wallet.
