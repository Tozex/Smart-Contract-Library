# Tozex Smart Contracts

## Smart Contracts that are used in Tozex Launchpad

The development of a smart contract code requires deep expertise in computer science, cryptography, and programming languages. The development must be accurate and optimized because each piece of code has an impact on cost execution and security. Rigorous testing and prototyping must be done before deploying a tradable token contract for crowdfunding or distribution.

Tozex library is open source, allowing anyone to check, audit, and contribute to our development. The first programming language of our library is based on Solidity to allow for deployment first on the Ethereum (ETH), Ethereum Classic (ETC), RootStock (RSK), Polygon,  Binance Smart Chain blockchain networks and any EVM Blockchain Solidity protocol. 

A) Fungible Token contract based on the ERC20 standard including some custom and audited functions by design like : 
	1) Vested Wallet or Smart contract function used to protect the interest of the project to ensure the entire control of your crypto assets from hackers, none compliant investors/wallets or undesirable market making bots.
	2) Burn and mint token function with EIP-2309, a Consecutive Transfer Extension, which enables minting any number of tokens in a single transaction to multiple wallets.
	3) Multi ownership function allowing to have a maximum of two owners to comply with a DAO demand.

B) Non Fungible Token Contract based on ERC721 standard including some customized and audited functions by design like : 
	1) EIP-2309, a Consecutive Transfer Extension, which enables minting any number of tokens in a single transaction to multiple wallets
  2) EIP-2981, a NFT Royalty Standard Extension allowing by marketplace during a sale of the NFT to notify and send the royalty amount directly to the wallet creator.

C) Automated Token Sale Contract (ICO / STO / BRO) compliant with all stabelcoins (USDT/USDC/BUSD/DAI) to automatically collect funds on an external wallet and distribute immediately your tokens. 

D) Multi-signature Token Contract to secure all fungible assets among co signers (until 10) used to deploy a specific governance token mechanism.






