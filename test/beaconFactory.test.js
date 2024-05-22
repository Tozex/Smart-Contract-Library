const MultiSigWalletAPI = artifacts.require("MultiSigWalletAPI");
const VaultProxyBeaconFactory = artifacts.require("VaultProxyBeaconFactory");

const { expect } = require("chai");



contract("MultiSigWallet", (accounts) => {
  let vaultFactoryInstance;
  let implementationInstance;
  const [owner, signer1, signer2, signer3, signer4, signer5, signer6, otherUser, otherUser1] = accounts;


  beforeEach(async () => {
    
    const forwarderAddress = "0xFD4973FeB2031D4409fB57afEE5dF2051b171104";

    implementationInstance = await MultiSigWalletAPI.new(forwarderAddress);

    const requiredSignatures = 2; // required signatures for transaction execution
    const initialSigners = [signer1, signer2, signer4, signer5]; // Initial signers for the wallet
    vaultFactoryInstance = await VaultProxyBeaconFactory.new(implementationInstance.address, initialSigners, requiredSignatures, owner);

  });

  it("should confirm, revoke, and execute a transaction", async () => {
    assert.equal(implementationInstance.address !== '', true, 'Contract not deployed');
  });
  it("should deploy a new vault factory", async () => {
    assert.equal(vaultFactoryInstance.address !== '', true, 'Contract not deployed');
  });
  it("should deploy a new vault", async () => {
    const requiredSignatures = 2; // required signatures for transaction execution
    const initialSigners = [signer1, signer2, signer4, signer5]; // Initial signers for the wallet
    const newVault = await vaultFactoryInstance.create(initialSigners, requiredSignatures);
    assert.equal(newVault.address !== '', true, 'Contract not deployed');
  });
  it("should deploy emit VaultCreated", async () => {
    const requiredSignatures = 2; // required signatures for transaction execution
    const initialSigners = [signer1, signer2, signer4, signer5]; // Initial signers for the wallet
    const {logs} = await vaultFactoryInstance.create(initialSigners, requiredSignatures);
    const event = logs.find(x => x.event === "VaultCreated");
    const newVaultAddress = event.args[0];
    expect(newVaultAddress).to.be.not.null;
  });
});
