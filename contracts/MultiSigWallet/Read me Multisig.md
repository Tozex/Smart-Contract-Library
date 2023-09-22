# MultiSigWallet

The MultiSigWallet has on goal to validate transfer transaction by several wallet limited to 10 maximum co signers managing at the same time multiple ERC20, ERC721, ERC1155 tokens and ETH or the blockchain's native token on the same contract.
The MultiSigWallet has two access role :
Owner : 1 only address. The address that initially deployed the contract (can be transferable). The owner can submit change of signer request and can't be a signer.
Signer : 10 maximum addresses. The signers can submit and confirm transactions and approve change of signer request.

More information : <https://medium.com/tozex/tozex-smart-contract-library-6aaca54ca871>.

### Variable

| Variable | Type | Description |
| ------ | ------ | ------ |
| transactions | public mapping (uint => Transaction) | Associate an id to each transaction
| confirmations | public mapping (uint => mapping (address => bool)) | Allowing to confirm or check a confirmation on a transaction by a signer
| signerChangeRequests | public mapping (address => address) | Stores the pending signer change requests
| isSigner | public mapping (address => bool)  | Variable used to check the wallet owner actions (submit or confirm transaction)
| signers | public address[] | Addresses of the signers of the multisig wallet
| signerCount | public uint | Number of signers of the multisig wallet
| required | public uint | Required number of signer's signature needed to execute a submitted transaction.
| transactionCount | public uint | Number of transactions on the MultisigWallet

### Variable Enum TokenStandard

This enum is used to identify the type of token used in the submitted transaction.

| Enum variable | Description |
| ------ | ------ |
| ERC20 | represents the ERC20 token
| ERC721 | represents the ERC721 token
| ERC1155 | represents the ERC1155 token
| USER | represents the native token of the blockchain used. For example, ETH on Ethereum

### Variable Struct Transaction

| Struct variable | Type | Description |
| ------ | ------ | ------ |
| executed  | bool | Check the state of a transaction, if it is executed or not
| destination | address | Ethereum Wallet where the "value" will be sent
| token | address | Address of the token contract, if the transaction is with the native token of the blockchain, you can put any address
| data | bytes | Method id of the submitted transaction
| ts | TokenStandard (Enum) | Type of token used in the submitted transaction (0 = ERC20, 1 = ERC721, 2 = ERC1155, 3 = USER)
| tokenId | uint | In case of ERC721 or ERC1155 token, the tokenId is used to identify the token, if the transaction is with a ERC20 or the native token of the blockchain, you can put any uint
| value | uint | Amount of tokens sent
| confirmTimestamp |  uint | The timestamp from which the transaction will expire. A zero value means you have an infinite time to confirm the submitted transaction.
| txTimestamp |  uint | The timestamp of when the transaction was submitted.

#### Function payable()

This function allows the MultisigWallet Contract to receive the native token of the blockchain. It emit an event.

#### Constructor

The constructor sets :

* The signers wallet address allowing them to interact with MultiSigWallet.
* Minimum number of signatures required to confirm a spendable transaction and signer change request.
* The owner wallet is set by default to the address that deployed the contract.

#### Function transferOwnership()

This function allows the owner to transfer the ownership of the MultiSigWallet to another address. The new owner can't be a signer.

#### Function requestSignerChange()

This function allows the owner to submit a request to change a signer. The new signer can't be the owner.

#### Function confirmSignerChange()

This function allows the signers to confirm a pending signer change request. The request is executed automatically when the required number of signatures is reached.

#### Functions depositERC20(), depositERC721() and depositERC1155()

This functions allows the deposit of ERC20, ERC721 and 1155 tokens on the MultiSigWallet when a allowance is set on the token contract.

#### Function submitTransaction()

This function allows signers to submit a transaction to be confirmed by signers. A signer submitting the spendable transaction is confirm it automatically.

#### Function confirmTransaction()

This function allows the signers to confirm a pending spendable transaction. If the number of confirmation is reached the spendable transaction is executed. If the cutoff timestamp to confirm the transaction has passed, the spendable transaction is permanently frozen and can no longer be confirmed and executed.

#### Function isConfirmed()

This function checks if a submitted spendable transaction has the number of requiered confirmation and had been execute.

#### Function getConfirmationCount()

This function checks the number of confirmation of a submitted spendable transaction received.

#### Function getTransactionCount()

This function checks the number of submitted spendable transactions.

#### Function getConfirmations()

This function returns the addresses of signers who confirmed a submitted spendable transaction.

#### Function getTransactionIds()

This function checks the data of spendable transaction (is the transaction id is include between "from" and "to", is the transaction pending, is the transaction executed). This function returns the transactions that corresponds to the parameters.

#### Functions on onERC721Received(), onERC1155Received(),and onERC1155BatchReceived()

These functions are used to receive ERC721 and ERC1155 tokens. See the ERC721 and ERC1155 documentation for more information.

#### Function addTransaction()

This function is called by submitTransaction() allowing to add a "transactionId" to identify the submitted transaction.

#### Function executeTransaction()

This function is called in confirmTransaction() when the number of signatures needed is reached allowing to execute the submitted spendable transaction.

#### Function isTransactionTimedOut()

This function is called in confirmTransaction(). When the remaining period is reached, confirmations can no longer take place so the transaction is permanently frozen

#### Function isSignerChangeConfirmed()

This function is called by confirmSignerChange(), it checks if a pending signer change request has the number of requiered confirmation needed to execute it. The function returns true if the required number of signers is reached.

#### Function removeSigner()

This function is called by confirmSignerChange(), it removes a signer from the MultiSigWallet when the required number of signatures is reached.

#### Function clearSignerChangeConfirmations()

This function called by confirmSignerChange() and requestSignerChange(), it clears the confirmations for the signer change request.

#### Function getNow()

This function returns the current timestamp.
