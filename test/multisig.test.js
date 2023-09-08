const MultiSigWallet = artifacts.require("MultiSigWallet");
const { expectRevert } = require('@openzeppelin/test-helpers');

const ERC20 = artifacts.require('MockERC20');
const ERC721 = artifacts.require('MockERC721');
const ERC1155 = artifacts.require('MockERC1155');

contract("MultiSigWallet", (accounts) => {
  let walletInstance;
  const [owner, signer1, signer2, signer3, signer4, signer5, signer6, otherUser, otherUser1] = accounts;


  beforeEach(async () => {
    const requiredSignatures = 2; // Number of required signatures for a transaction
    const initialSigners = [signer1, signer2, signer4, signer5]; // Initial signers for the wallet

    walletInstance = await MultiSigWallet.new(initialSigners, requiredSignatures, {from: owner});

    erc20 = await ERC20.new("Tozex token", "TOZ", {from: owner});
    erc721 = await ERC721.new({from: owner});
    erc1155 = await ERC1155.new({from: owner});
    await erc20.mint(walletInstance.address, web3.utils.toWei("100000000", "ether"), {from:owner});
    await erc721.mint(walletInstance.address, 1, {from:owner});
    await erc721.mint(walletInstance.address, 2, {from:owner});
    await erc1155.mint(walletInstance.address, 1, 1000, "0x", {from:owner});
    await erc1155.mint(walletInstance.address, 2, 1000, "0x", {from:owner});
  });

  it("should confirm, revoke, and execute a transaction", async () => {
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
    const destinationBalance = await web3.eth.getBalance(destinationAddress);
    assert.equal(destinationBalance, transactionValue, "Destination balance should increase by the transaction value");
  });

  it("should confirm, revoke, and execute an ERC721 transaction", async () => {
    const destinationAddress = otherUser;
    const tokenId = 1;

    // Submit a transaction to transfer ERC721 token
    const submitTxReceipt = await walletInstance.submitTransaction(
      destinationAddress,
      erc721.address, // Address of the ERC721 token contract
      1, // Token Standard (0: Ether, 1: ERC20, 2: ERC721, 3: ERC1155, 4: User-defined)
      tokenId,
      0, // Transaction value (not used for ERC721 transactions)
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

    // Check if the ERC721 token is now owned by the wallet contract
    const ownerOfToken = await erc721.ownerOf(tokenId);
    assert.equal(ownerOfToken, destinationAddress, "The ERC721 token should be owned by the wallet contract");
  });

  it("should confirm, revoke, and execute an ERC1155 transaction", async () => {
    const transactionValue = 100;
    const destinationAddress = otherUser;
    const tokenId = 1;

    // Submit a transaction to transfer ERC1155 tokens
    const submitTxReceipt = await walletInstance.submitTransaction(
      destinationAddress,
      erc1155.address, // Address of the ERC1155 token contract
      2, // Token Standard (0: Ether, 1: ERC20, 2: ERC721, 3: ERC1155, 4: User-defined)
      tokenId,
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

    // Check if the ERC1155 tokens are now owned by the wallet contract
    const balanceInWallet = await erc1155.balanceOf(destinationAddress, tokenId);
    assert.equal(balanceInWallet.toString(), transactionValue.toString(), "The ERC1155 tokens should be in the wallet contract");
  });

  it("should revert when confirming an already confirmed transaction", async () => {
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

    // Try to confirm the transaction again by signer1
    await expectRevert(
      walletInstance.confirmTransaction(transactionId, { from: signer2 }),
      "Transaction already confirmed"
    );
  });

  it("should confirm a signer change request", async () => {
    // Request a signer change by the owner
    await walletInstance.requestSignerChange(signer1, signer3, { from: owner });

    // Confirm the signer change by the new signer
    await walletInstance.confirmSignerChange(signer1, signer3, { from: signer2 });

    // Check if the new signer has been added
    assert.equal(await walletInstance.isSigner(signer3), false, "New signer should not be added");

    // Confirm the signer change by the new signer
    await walletInstance.confirmSignerChange(signer1, signer3, { from: signer4 });

    // Check if the new signer has been added
    assert.equal(await walletInstance.isSigner(signer3), false, "New signer should not be added");

    // Confirm the signer change by the new signer
    await walletInstance.confirmSignerChange(signer1, signer3, { from: signer5 });

    // Check if the new signer has been added
    assert.isTrue(await walletInstance.isSigner(signer3), "New signer should be added");
  });

  it("should revert when confirming a signer change with an invalid new signer", async () => {
    // Request a signer change by the owner
    await walletInstance.requestSignerChange(signer1, signer3, { from: owner });

    // Try to confirm the signer change with an invalid new signer
    await expectRevert(
      walletInstance.confirmSignerChange(signer1, otherUser, { from: signer2 }),
      "New signer address invalid."
    );
  });

  it("should revert when trying to confirm a signer change without a pending request", async () => {
    // Try to confirm a signer change without a pending request
    await expectRevert(
      walletInstance.confirmSignerChange(signer1, signer3, { from: signer2 }),
      "New signer address invalid."
    );
  });

  it("should revert when trying to confirm a signer change with an already existing signer", async () => {
    // Request a signer change by the owner
    await walletInstance.requestSignerChange(signer1, signer3, { from: owner });

    // Confirm the signer change by the new signer
    await walletInstance.confirmSignerChange(signer1, signer3, { from: signer2 });
    await walletInstance.confirmSignerChange(signer1, signer3, { from: signer4 });
    await walletInstance.confirmSignerChange(signer1, signer3, { from: signer5 });
    
    assert.equal(await walletInstance.isSigner(signer1), false, "signer change confirmed");
    assert.isTrue(await walletInstance.isSigner(signer3), "signer change confirmed");

    // Try to confirm the signer change again with the same new signer
    await expectRevert(
      walletInstance.confirmSignerChange(signer1, signer3, { from: signer2 }),
      "New signer address invalid."
    );

    assert.equal(await walletInstance.signerChangeConfirmations(signer3, signer2), false, "confirmation cleared");
    assert.equal(await walletInstance.signerChangeConfirmations(signer3, signer4), false, "confirmation cleared");
    assert.equal(await walletInstance.signerChangeConfirmations(signer3, signer5), false, "confirmation cleared");
  });

  it("should reset signerChangeConfirmations when request again", async () => {
    // Request a signer change by the owner
    await walletInstance.requestSignerChange(signer1, signer3, { from: owner });

    // Confirm the signer change by the new signer
    await walletInstance.confirmSignerChange(signer1, signer3, { from: signer2 });

    assert.isTrue(await walletInstance.signerChangeConfirmations(signer3, signer2), "Confirmed by signer2");

    await walletInstance.requestSignerChange(signer1, signer6, { from: owner });

    assert.equal(await walletInstance.signerChangeConfirmations(signer3, signer2), false, "confirmation cleared");
  });

  it("should revert when trying to transferOwnership to signer", async () => {
    await expectRevert(
      walletInstance.transferOwnership(signer1, { from: owner }),
      "Ownable: new owner cannot be signer."
    );
  });
});
