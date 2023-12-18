
const { ethers, waffle, upgrades } = require("hardhat");
const { Wallet } = require("ethers");

const { expect } = require('chai');
const ether = require("@openzeppelin/test-helpers/src/ether");


function seconds_since_epoch(){ 
    var d = new Date();
    return Math.floor( d.getTime() / 1000 ); 
}
  

describe("BridgeAssist", function () {
    let dps;
    let usdc;
    let toz;
    let ico;
    let multisig;
    let beconProxy;
    let signer1;
    let signer2;
    let signer3;
    let owner;
    let investor1;
    let investor2;
    let investor3;
    const tokenSupply = ethers.BigNumber.from('1000000000000000000000000');
    const softCap = ethers.BigNumber.from('10000000000000000000000');
    const maxCap = ethers.BigNumber.from('20000000000000000000000');
    const tozDecimal = ethers.BigNumber.from(10).pow(18);
    const usdcDecimal = ethers.BigNumber.from(10).pow(6);
    before(async function () {
        [owner, signer1, signer2, signer3, investor1, investor2, investor3] = await ethers.getSigners();
        dps = await ethers.deployContract("MockToken", ["DPS token", "DPS"]);
        await dps.deployed();
        usdc = await ethers.deployContract("MockToken", ["USDC", "USDC"]);
        await usdc.deployed();
        toz = await ethers.deployContract("MockToken", ["Tozex Token", "TOZ"]);
        await toz.deployed();
        ico = await ethers.deployContract("ICOMultisig", [toz.address, usdc.address, dps.address, 600, 75,  softCap, maxCap]);
        await ico.deployed();

        const multisigImpl = await hre.ethers.deployContract('MultiSigWallet');
        await multisigImpl.deployed();
        const MultiSigWallet = await ethers.getContractFactory("MultiSigWallet");
        const beacon = await ethers.deployContract("UpgradeableBeaconMultisig", [multisigImpl.address, [signer1.address, signer2.address, signer3.address], 2]);
        await beacon.deployed();

        beconProxy = await upgrades.deployBeaconProxy(beacon.address, MultiSigWallet, [[signer1.address, signer2.address, signer3.address, ico.address], 3]);

        await beconProxy.deployed();
        await ico.setMultisig(beconProxy.address);

        await dps.mint(ico.address, tokenSupply);
        await toz.mint(investor1.address, tokenSupply);
        await usdc.mint(investor1.address, tokenSupply);
        await toz.mint(investor2.address, tokenSupply);
        await usdc.mint(investor2.address, tokenSupply);
        await toz.mint(investor3.address, tokenSupply);
        await usdc.mint(investor3.address, tokenSupply);
    });

    describe("test", function () {
        it("test", async function () {
          expect(await beconProxy.signers(3)).to.equal(ico.address);
        });
    });


    describe('buyTokens', function () {
        describe('validate', function() {
            it('revert because contract paused', async function () {
                await ico.connect(owner).pause();
                await expect(ico.connect(investor1).buyTokens(0, ethers.BigNumber.from("100").mul(tozDecimal))).be.reverted;
            });

            it('revert because ICO is already finished', async function () {
                await ico.connect(owner).unpause();
                await ico.connect(owner).setIco( false);
                await expect(ico.connect(investor1).buyTokens(0, ethers.BigNumber.from("100").mul(tozDecimal))).be.revertedWith("ICO.buyTokens: ICO is already finished.");
            });
    
            it('revert because deposit amount is less than min purchase amount', async function () {
                await ico.connect(owner).setIco(true);
                await expect(ico.connect(investor1).buyTokens(0, ethers.BigNumber.from("50").mul(tozDecimal))).be.revertedWith("ICO.buyTokens: Failed the amount is not respecting the minimum deposit of ICO");

                await expect(ico.connect(investor1).buyTokens(1, ethers.BigNumber.from("5").mul(usdcDecimal))).be.revertedWith("ICO.buyTokens: Failed the amount is not respecting the minimum deposit of ICO");
            });

            it('revert because deposit token not approved', async function () {
                await expect(ico.connect(investor1).buyTokens(0, ethers.BigNumber.from("120").mul(tozDecimal))).be.revertedWith("ERC20: insufficient allowance");
            });

            it('revert because user already deposit another token', async function () {
                await toz.connect(investor1).approve(ico.address, ethers.BigNumber.from("120").mul(tozDecimal));
                await ico.connect(investor1).buyTokens(0, ethers.BigNumber.from("120").mul(tozDecimal));
                await usdc.connect(investor1).approve(ico.address, ethers.BigNumber.from("75").mul(usdcDecimal));
                await expect(ico.connect(investor1).buyTokens(1, ethers.BigNumber.from("75").mul(usdcDecimal))).be.revertedWith("You already selected another token for payment");
            });
        });
        
        describe('Soft Cap', function() {
            it('Toz token should go to multisig contract', async function () {
                const beforeBalance = await toz.balanceOf(beconProxy.address);
                await expect(beforeBalance).to.equal(0);
                await toz.connect(investor1).approve(ico.address, ethers.BigNumber.from("120").mul(tozDecimal));
                await ico.connect(investor1).buyTokens(0, ethers.BigNumber.from("120").mul(tozDecimal));
                const afterBalance = await toz.balanceOf(beconProxy.address);
                await expect(afterBalance).to.equal(ethers.BigNumber.from("120").mul(tozDecimal));
            });
            it('User deposit amount should be stored for toz deposit', async function () {
                const userDetail = await ico.userDetails(investor1.address);
                await expect(userDetail.tt).to.equal(0);
                await expect(userDetail.depositAmount).to.equal(ethers.BigNumber.from("120").mul(tozDecimal));
                await expect(userDetail.totalRewardAmount).to.equal(ethers.BigNumber.from("20").mul(tozDecimal));
                await expect(userDetail.remainingAmount).to.equal(ethers.BigNumber.from("20").mul(tozDecimal));
            });
            it('Usdc token should go to multisig contract', async function () {
                const beforeBalance = await usdc.balanceOf(beconProxy.address);
                await expect(beforeBalance).to.equal(0);
                await usdc.connect(investor2).approve(ico.address, ethers.BigNumber.from("75").mul(usdcDecimal));
                await ico.connect(investor2).buyTokens(1, ethers.BigNumber.from("75").mul(usdcDecimal));
                const afterBalance = await usdc.balanceOf(beconProxy.address);
                await expect(afterBalance).to.equal(ethers.BigNumber.from("75").mul(usdcDecimal));
            });
            it('User deposit amount should be stored for usdc deposit', async function () {
                const userDetail = await ico.userDetails(investor2.address);
                await expect(userDetail.tt).to.equal(1);
                await expect(userDetail.depositAmount).to.equal(ethers.BigNumber.from("75").mul(usdcDecimal));
                await expect(userDetail.totalRewardAmount).to.equal(ethers.BigNumber.from("100").mul(tozDecimal));
                await expect(userDetail.remainingAmount).to.equal(ethers.BigNumber.from("100").mul(tozDecimal));
            });
            it('Only new user can be added to userAddresses', async function () {
                await toz.connect(investor1).approve(ico.address, ethers.BigNumber.from("240").mul(tozDecimal));
                await ico.connect(investor1).buyTokens(0, ethers.BigNumber.from("240").mul(tozDecimal));
                const userDetail = await ico.userDetails(investor1.address);
                await expect(userDetail.tt).to.equal(0);
                await expect(userDetail.depositAmount).to.equal(ethers.BigNumber.from("360").mul(tozDecimal));
                await expect(userDetail.totalRewardAmount).to.equal(ethers.BigNumber.from("60").mul(tozDecimal));
                await expect(userDetail.remainingAmount).to.equal(ethers.BigNumber.from("60").mul(tozDecimal));
                const user1 = await ico.userAddresses(0);
                const user2 = await ico.userAddresses(1);
                await expect(user1).to.equal(investor1.address);
                await expect(user2).to.equal(investor2.address);
                await expect(ico.userAddresses(2)).be.reverted;
            });
            it('Check totalDepositAmount', async function () {
                const totalDepositAmount = await ico.totalDepositAmount();
                expect(totalDepositAmount, ethers.BigNumber.from("160").mul(tozDecimal));
            });
            it('Deposit until softcap is reached', async function () {
                let user1DpsBalance = await dps.balanceOf(investor1.address);
                let user2DpsBalance = await dps.balanceOf(investor2.address);
                let user3DpsBalance = await dps.balanceOf(investor3.address);
                await expect(user1DpsBalance).to.equal(ethers.BigNumber.from("0").mul(tozDecimal));
                await expect(user2DpsBalance).to.equal(ethers.BigNumber.from("0").mul(tozDecimal));
                await expect(user3DpsBalance).to.equal(ethers.BigNumber.from("0").mul(tozDecimal));

                await toz.connect(investor1).approve(ico.address, ethers.BigNumber.from("30000").mul(tozDecimal));
                await ico.connect(investor1).buyTokens(0, ethers.BigNumber.from("30000").mul(tozDecimal));
                let user1Detail = await ico.userDetails(investor1.address);
                await expect(user1Detail.remainingAmount).to.equal(ethers.BigNumber.from("5060").mul(tozDecimal));

                await usdc.connect(investor2).approve(ico.address, ethers.BigNumber.from("2250").mul(usdcDecimal));
                await ico.connect(investor2).buyTokens(1, ethers.BigNumber.from("2250").mul(usdcDecimal));
                let user2Detail = await ico.userDetails(investor2.address);
                await expect(user2Detail.remainingAmount).to.equal(ethers.BigNumber.from("3100").mul(tozDecimal));

                await toz.connect(investor3).approve(ico.address, ethers.BigNumber.from("6000").mul(tozDecimal));
                await ico.connect(investor3).buyTokens(0, ethers.BigNumber.from("6000").mul(tozDecimal));
                let user3Detail = await ico.userDetails(investor3.address);
                await expect(user3Detail.remainingAmount).to.equal(ethers.BigNumber.from("1000").mul(tozDecimal));
                
                await toz.connect(investor3).approve(ico.address, ethers.BigNumber.from("12000").mul(tozDecimal));
                await ico.connect(investor3).buyTokens(0, ethers.BigNumber.from("12000").mul(tozDecimal));
                user1Detail = await ico.userDetails(investor1.address);
                user2Detail = await ico.userDetails(investor2.address);
                user3Detail = await ico.userDetails(investor3.address);
                await expect(user1Detail.remainingAmount).to.equal(ethers.BigNumber.from("0").mul(tozDecimal));
                await expect(user2Detail.remainingAmount).to.equal(ethers.BigNumber.from("0").mul(tozDecimal));
                await expect(user3Detail.remainingAmount).to.equal(ethers.BigNumber.from("0").mul(tozDecimal));

                const totalDepositAmount = await ico.totalDepositAmount();
                expect(totalDepositAmount).to.equal(ethers.BigNumber.from("11160").mul(tozDecimal));

                user1DpsBalance = await dps.balanceOf(investor1.address);
                user2DpsBalance = await dps.balanceOf(investor2.address);
                user3DpsBalance = await dps.balanceOf(investor3.address);
                await expect(user1DpsBalance).to.equal(ethers.BigNumber.from("5060").mul(tozDecimal));
                await expect(user2DpsBalance).to.equal(ethers.BigNumber.from("3100").mul(tozDecimal));
                await expect(user3DpsBalance).to.equal(ethers.BigNumber.from("3000").mul(tozDecimal));
            });

            it('Transfer DPS on buyToken transaction after softcap is reached', async function () {
                await toz.connect(investor1).approve(ico.address, ethers.BigNumber.from("6000").mul(tozDecimal));
                await ico.connect(investor1).buyTokens(0, ethers.BigNumber.from("6000").mul(tozDecimal));
                let user1Detail = await ico.userDetails(investor1.address);
                await expect(user1Detail.totalRewardAmount).to.equal(ethers.BigNumber.from("6060").mul(tozDecimal));
                await expect(user1Detail.remainingAmount).to.equal(ethers.BigNumber.from("0").mul(tozDecimal));
                const user1DpsBalance = await dps.balanceOf(investor1.address);
                await expect(user1DpsBalance).to.equal(ethers.BigNumber.from("6060").mul(tozDecimal));
            });

            it('Update the softcap', async function () {
                await ico.connect(owner).updateIcoSoftCap(ethers.BigNumber.from("20000").mul(tozDecimal));
                await toz.connect(investor1).approve(ico.address, ethers.BigNumber.from("6000").mul(tozDecimal));
                await ico.connect(investor1).buyTokens(0, ethers.BigNumber.from("6000").mul(tozDecimal));
                let user1Detail = await ico.userDetails(investor1.address);
                await expect(user1Detail.totalRewardAmount).to.equal(ethers.BigNumber.from("7060").mul(tozDecimal));
                await expect(user1Detail.remainingAmount).to.equal(ethers.BigNumber.from("1000").mul(tozDecimal));
            });
        });

        describe('Refund', function() {
            it('Deposit token', async function () {
                await toz.connect(investor1).approve(ico.address, ethers.BigNumber.from("30000").mul(tozDecimal));
                await ico.connect(investor1).buyTokens(0, ethers.BigNumber.from("30000").mul(tozDecimal));

                await usdc.connect(investor2).approve(ico.address, ethers.BigNumber.from("2250").mul(usdcDecimal));
                await ico.connect(investor2).buyTokens(1, ethers.BigNumber.from("2250").mul(usdcDecimal));

                await toz.connect(investor3).approve(ico.address, ethers.BigNumber.from("6000").mul(tozDecimal));
                await ico.connect(investor3).buyTokens(0, ethers.BigNumber.from("6000").mul(tozDecimal));

                const tozBalance = await toz.balanceOf(beconProxy.address);
                await expect(tozBalance).to.equal(ethers.BigNumber.from("36000").mul(tozDecimal));
                const usdcBalance = await usdc.balanceOf(beconProxy.address);
                await expect(usdcBalance).to.equal(ethers.BigNumber.from("2250").mul(usdcDecimal));
            });
            it('Request refund', async function () {
                await ico.connect(owner).requestRefund();
                const tozRefund = await beconProxy.transactions(0);
                await expect(tozRefund.value).to.equal(ethers.BigNumber.from("36000").mul(tozDecimal));
                const usdcRefund = await beconProxy.transactions(1);
                await expect(usdcRefund.value).to.equal(ethers.BigNumber.from("2250").mul(usdcDecimal));
            });
            it('Confirm transaction', async function () {
                const tozBeforeBalance = await toz.balanceOf(ico.address);
                await expect(tozBeforeBalance).to.equal(ethers.BigNumber.from("0").mul(tozDecimal));
                await beconProxy.connect(signer1).confirmTransaction(0);
                await beconProxy.connect(signer2).confirmTransaction(0);
                const tozAfterBalance = await toz.balanceOf(ico.address);
                await expect(tozAfterBalance).to.equal(ethers.BigNumber.from("36000").mul(tozDecimal));

                const usdcBeforeBalance = await usdc.balanceOf(ico.address);
                await expect(usdcBeforeBalance).to.equal(ethers.BigNumber.from("0").mul(usdcDecimal));
                await beconProxy.connect(signer1).confirmTransaction(1);
                await beconProxy.connect(signer2).confirmTransaction(1);
                const usdcAfterBalance = await usdc.balanceOf(ico.address);
                await expect(usdcAfterBalance).to.equal(ethers.BigNumber.from("2250").mul(usdcDecimal));
            });
            it('Refund token', async function () {
                const investor1BeforeBalance = await toz.balanceOf(investor1.address);
                const investor2BeforeBalance = await usdc.balanceOf(investor2.address);
                const investor3BeforeBalance = await toz.balanceOf(investor3.address);
                await ico.connect(owner).refundToken();

                const investor1afterBalance = await toz.balanceOf(investor1.address);
                const investor2afterBalance = await usdc.balanceOf(investor2.address);
                const investor3afterBalance = await toz.balanceOf(investor3.address);
                await expect(investor1afterBalance.sub(investor1BeforeBalance)).to.equal(ethers.BigNumber.from("30000").mul(tozDecimal));
                await expect(investor2afterBalance.sub(investor2BeforeBalance)).to.equal(ethers.BigNumber.from("2250").mul(usdcDecimal));
                await expect(investor3afterBalance.sub(investor3BeforeBalance)).to.equal(ethers.BigNumber.from("6000").mul(tozDecimal));

                const user1Detail = await ico.userDetails(investor1.address);
                const user2Detail = await ico.userDetails(investor2.address);
                const user3Detail = await ico.userDetails(investor3.address);
                await expect(user1Detail.depositAmount).to.equal(ethers.BigNumber.from("0"));
                await expect(user1Detail.totalRewardAmount).to.equal(ethers.BigNumber.from("0"));
                await expect(user1Detail.remainingAmount).to.equal(ethers.BigNumber.from("0"));

                await expect(user2Detail.depositAmount).to.equal(ethers.BigNumber.from("0"));
                await expect(user2Detail.totalRewardAmount).to.equal(ethers.BigNumber.from("0"));
                await expect(user2Detail.remainingAmount).to.equal(ethers.BigNumber.from("0"));

                await expect(user3Detail.depositAmount).to.equal(ethers.BigNumber.from("0"));
                await expect(user3Detail.totalRewardAmount).to.equal(ethers.BigNumber.from("0"));
                await expect(user3Detail.remainingAmount).to.equal(ethers.BigNumber.from("0"));
            });
        });
    });

    describe('Withdraw Tokens', function() {
        it('Withdraw DPS', async function () {
            const dpsBeforeBalance = await dps.balanceOf(ico.address);
            expect(dpsBeforeBalance).to.equal(tokenSupply);
            await ico.connect(owner).withdrawtoken(signer3.address);
            const dpsAfterBalance = await dps.balanceOf(ico.address);
            expect(dpsAfterBalance).to.equal(0);
            const signer3Balance = await dps.balanceOf(signer3.address);
            expect(signer3Balance).to.equal(tokenSupply);
        });
    });
});
