const MultiSigWalletAPI = artifacts.require("MultiSigWalletAPI");
const { expectRevert } = require('@openzeppelin/test-helpers');
const { assert } = require('chai');

const VaultProxyBeaconFactory = artifacts.require("VaultProxyBeaconFactory");


const ERC20 = artifacts.require('MockToken');

contract("MultiSigWalletAPI", (accounts) => {
  let walletInstance;
  let implementationInstance;

  const [owner, signer1, signer2, signer3, signer4, signer5, signer6, otherUser, vaultOwner] = accounts;

  let vaultFactoryInstance;
  const initialSigners = [signer1, signer2, signer4, signer5]; // Initial signers for the wallet
  const requiredSignatures = 2; // Number of required signatures for a transaction
  const forwarderAddress = "0xFD4973FeB2031D4409fB57afEE5dF2051b171104";
  const identifier = "1";
  beforeEach(async () => {

    implementationInstance = await MultiSigWalletAPI.new(forwarderAddress);

    vaultFactoryInstance = await VaultProxyBeaconFactory.new(implementationInstance.address, initialSigners, requiredSignatures, { from: owner });

    const {logs} = await vaultFactoryInstance.create(initialSigners, requiredSignatures, identifier, {from: owner});
    const event = logs.find(x => x.event === "VaultCreated");
    const newVaultAddress = event.args[0];
    erc20 = await ERC20.new("Tozex token", "TOZ", { from: owner });
    await erc20.mint(newVaultAddress, web3.utils.toWei("100000000", "ether"), { from: owner });
    walletInstance = await MultiSigWalletAPI.at(newVaultAddress);
  });

  it("should confirm and execute a transaction", async () => {
    const transactionValue = web3.utils.toWei("100", "ether");
    const destinationAddress = otherUser;

    // Submit a transaction
    const submitTxReceipt = await walletInstance.submitTransaction(
      destinationAddress,
      erc20.address, // Address of the token (use 0x0 for Ether transactions)
      0, // Token Standard (0: Ether, 1: ERC20, 2: ERC721, 3: ERC1155, 4: User-defined)
      0, // Token ID (0 for Ether, or specific token ID for ERC20/ERC721/ERC1155)
      transactionValue,
      "0x", // Empty data
      0, // Confirm Timestamp (0 for immediate confirmation)
      { from: signer1 }
    );

    const transactionId = submitTxReceipt.logs[0].args.transactionId.toNumber();

    // Confirm the transaction by signer1 and signer2
    await walletInstance.confirmTransaction(transactionId, { from: signer2 });

    // Check if the transaction has been executed
    const executionStatus = await walletInstance.transactions(transactionId);
    assert.isTrue(executionStatus.executed, "Transaction should be executed");

    // Check if the balance of the destination address has increased
    const destinationBalance = await erc20.balanceOf(destinationAddress);
    assert.equal(destinationBalance, transactionValue, "Destination balance should increase by the transaction value");
  });
  it("vault owner should the defined address", async () => {
    assert.equal(await walletInstance.owner(), owner, "the vault owner should be the defined address");
  });
  it("should match the vaultOwner for new created vault", async () => {

    const {logs} = await vaultFactoryInstance.create(initialSigners, requiredSignatures, identifier, {from: vaultOwner});
    const event = logs.find(x => x.event === "VaultCreated");
    const newVaultAddress = event.args[0];
    const walletInstance2 = await MultiSigWalletAPI.at(newVaultAddress);
    assert.equal(await walletInstance2.owner(), vaultOwner, "the vault owner should be the defined address");
    
  });
  it("Should be able to update the ownership of the vault factory", async () => {
    await vaultFactoryInstance.transferOwnership(signer2, { from: owner });
    assert.equal(await vaultFactoryInstance.owner(), signer2, "the forwarder address should be the defined address");
  });
  it("Should be able to update the ownership of the vault", async () => {
    await walletInstance.transferOwnership(signer2, { from: owner });
    assert.equal(await walletInstance.owner(), signer2, "the forwarder address should be the defined address");
  });
});
