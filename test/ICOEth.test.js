const { BN, constants, expectEvent, time, expectRevert, ether, balance } = require('@openzeppelin/test-helpers');
const { ZERO_ADDRESS } = constants;

const { expect } = require('chai');

// const AccessControls = artifacts.require('AccessControls');
const ERC20 = artifacts.require('TokenContract');
const DAI = artifacts.require('MockERC20');
// const VestingToken = artifacts.require('VestingToken');
const ICO = artifacts.require('ICOEth');


function seconds_since_epoch(){ 
    var d = new Date();
    return Math.floor( d.getTime() / 1000 ); 
}
  

contract('ICO Test', function ([owner, masterWallet, investor1, investor2, investor3]) {

    const name = 'DAI coin';
    const symbol = 'DAI';
    const decimal = new BN('18');


    const tokenSupply = new BN('100000000000000000000000000');
    const seed_sale_token = new BN('10000000000000000000000000');
    const ONE_HUNDRED_TOKENS = new BN('100000000000000000000');
    const TEN_TOKEN = new BN('10000000000000000000');
    const FIVE_TOKENS = new BN('5000000000000000000');
    const TWO_TOKENS = new BN('2000000000000000000');
    const ONE_TOKEN = new BN('1000000000000000000');
    const bidAmount = new BN('200000000000000');
    const REMAINING_TOKENS = new BN('99000000000000000000');
    const Thirty_days = new BN('2592000');

    before(async function () {
        this.token = await ERC20.new("Tozex token", "TOZ", new BN('18'), {from: owner});
        this.daiToken = await DAI.new("DAI COIN", "DAI", {from: owner});
        this.ico = await ICO.new(masterWallet, this.token.address, new BN('18'), ONE_HUNDRED_TOKENS, new BN('20000000000000'), {from: owner});
        await this.daiToken.mint(owner, tokenSupply, {from: owner});
        await this.daiToken.transfer(investor1, ONE_HUNDRED_TOKENS, {from:owner});
        await this.daiToken.transfer(investor2, ONE_HUNDRED_TOKENS, {from:owner});
        await this.token.mint(owner, tokenSupply, {from: owner});
        // this.seedSale = await SeedSale.new(this.token.address, this.accessControls.address, this.vestingContract.address, masterWallet, startTime);
        
    });


    describe('buyTokens', function () {
        describe('validate', function() {
            it('revert because contract paused', async function () {
                await this.ico.pause({from:owner});
                await expectRevert.unspecified(this.ico.buyTokens({from:investor1, value: bidAmount}));
            });

            it('revert because ICO is already finished', async function () {
                await this.ico.unpause({from:owner});
                await this.ico.setIco( false, {from:owner});
                await expectRevert(this.ico.buyTokens({from:investor1, value: bidAmount}), "ICO.buyTokens: ICO is already finished.");
            });
    
            it('revert because deposit amount is less than min purchase amount', async function () {
                await this.ico.setIco( true, {from:owner});
                await expectRevert(this.ico.buyTokens({from:investor1, value: new BN('1000000000')}), "ICO.buyTokens: Failed the amount is not respecting the minimum deposit of ICO");
            });

            it('revert because ICO contract doesnt have reward token', async function () {
                await this.ico.setIco( true, {from:owner});
                // await this.daiToken.approve(this.ico.address, TEN_TOKEN, {from: investor1});
                const balance = await this.token.balanceOf(this.ico.address);
                await expectRevert(this.ico.buyTokens({from:investor1, value: bidAmount}), "ICO.buyTokens: not enough token to send");
            });

            it('revert because ICO contract doesnt have enough reward token', async function () {
                await this.token.transfer(this.ico.address, TEN_TOKEN, {from: owner});
                await this.ico.buyTokens({from:investor1, value: bidAmount});
                await expectRevert(this.ico.buyTokens({from:investor2, from :bidAmount}), "ICO.buyTokens: not enough token to send");
            });

            it('revert because ICO contract doesnt have enough reward token', async function () {
                await this.token.transfer(this.ico.address, ONE_TOKEN, {from: owner});
                let currentTime = await time.latest();
                await this.ico.updateUnlockTime(new BN(currentTime.add(new BN('1'))), {from: owner});
                await time.increase(new BN('1'));
                await expectRevert(this.ico.buyTokens( {from:investor1, value: bidAmount}), "ICO.buyTokens: Buy period already finished.");
            });

            // it('revert because deposit token not approved', async function () {
            //     await this.ico.setIco( true, {from:owner});
            //     // await this.token.transfer(this.ico.address, FIVE_TOKENS, {from: owner});
            //     await expectRevert(this.ico.buyTokens(TEN_TOKEN, {from:investor3}), "ERC20: transfer amount exceeds allowance.");
            // });
        });
        

        describe('buyTokens success', async function () {
            before(async function () {
                this.token = await ERC20.new("Tozex token", "TOZ", new BN('18'), {from: owner});
                await this.token.mint(owner, tokenSupply, {from: owner});
                this.ico = await ICO.new(masterWallet, this.token.address, new BN('18'), ONE_HUNDRED_TOKENS, new BN('20000000000000'), {from: owner});
                await this.token.transfer(this.ico.address, ONE_HUNDRED_TOKENS, {from: owner});
                let currentTime = await time.latest();
                await this.ico.updateUnlockTime(new BN(currentTime.add(new BN('10000'))), {from: owner});
            });
            it('buyTokens', async function () {
                const bidderTracker = await balance.tracker(masterWallet);
                await this.ico.buyTokens( {from:investor1, value: bidAmount});
                const changes = await bidderTracker.delta('wei');
                expect(changes).to.be.bignumber.equal('200000000000000');
                const userDetail = await this.ico.userDetails(investor1);
                expect(userDetail.totalRewardAmount).to.be.bignumber.equal('10000000000000000000');
                expect(userDetail.depositAmount).to.be.bignumber.equal('200000000000000');
                expect(userDetail.withdrawAmount).to.be.bignumber.equal('0');
            });
            it('buyTokens by 1st investor again', async function () {
                const bidderTracker = await balance.tracker(masterWallet);
                await this.ico.buyTokens( {from:investor1, value: bidAmount});
                const changes = await bidderTracker.delta('wei');
                expect(changes).to.be.bignumber.equal('200000000000000');
                const userDetail = await this.ico.userDetails(investor1);
                expect(userDetail.totalRewardAmount).to.be.bignumber.equal('20000000000000000000');
                expect(userDetail.depositAmount).to.be.bignumber.equal('400000000000000');
                expect(userDetail.withdrawAmount).to.be.bignumber.equal('0');
            });
            it('buyTokens by 2nd investor (check decimals)', async function () {
                const bidderTracker = await balance.tracker(masterWallet);
                await this.ico.buyTokens( {from:investor2, value: new BN('213000000000000')});
                const changes = await bidderTracker.delta('wei');
                expect(changes).to.be.bignumber.equal('213000000000000');
                const userDetail = await this.ico.userDetails(investor2);
                expect(userDetail.totalRewardAmount).to.be.bignumber.equal('10650000000000000000');
                expect(userDetail.depositAmount).to.be.bignumber.equal('213000000000000');
                expect(userDetail.withdrawAmount).to.be.bignumber.equal('0');
            });
            
        });
        describe('buyTokens - check decimals', function () {
            it('buyTokens by 2nd investor (check decimals)', async function () {

                this.token = await ERC20.new("Tozex token", "TOZ", new BN('9'), {from: owner});
                this.ico = await ICO.new(masterWallet, this.token.address, new BN('9'), ONE_HUNDRED_TOKENS, new BN('20000000000000'), {from: owner});
                await this.token.mint(owner, tokenSupply, {from: owner});
                await this.token.transfer(this.ico.address, ONE_HUNDRED_TOKENS, {from: owner});

                const bidderTracker = await balance.tracker(masterWallet);
                await this.ico.buyTokens( {from:investor1, value: bidAmount});
                const changes = await bidderTracker.delta('wei');
                expect(changes).to.be.bignumber.equal('200000000000000');
                const userDetail = await this.ico.userDetails(investor1);
                expect(userDetail.totalRewardAmount).to.be.bignumber.equal('10000000000');
                expect(userDetail.depositAmount).to.be.bignumber.equal('200000000000000');
                expect(userDetail.withdrawAmount).to.be.bignumber.equal('0');
            });
        }
        )
    });

    describe('Claim Token', function () {
        before(async function () {
            this.token = await ERC20.new("Tozex token", "TOZ", new BN('18'), {from: owner});
            await this.token.unlockToken({from: owner});
            await this.token.mint(owner, tokenSupply, {from: owner});
            this.ico = await ICO.new(masterWallet, this.token.address, new BN('18'), ONE_HUNDRED_TOKENS, new BN('20000000000000'), {from: owner});
            await this.token.transfer(this.ico.address, ONE_HUNDRED_TOKENS, {from: owner});
            await this.ico.buyTokens( {from:investor1, value: bidAmount});
        })
        describe('validate', function() {
            it('revert because contract paused', async function () {
                await this.ico.pause({from:owner});
                await expectRevert.unspecified(this.ico.claimTokens({from:investor1}));
            });

            it('revert because ICO is not finished', async function () {
                await this.ico.unpause({from:owner});
                await this.ico.setIco( true, {from:owner});
                await expectRevert(this.ico.claimTokens({from:investor1}), "ICO.claimTokens: ico is not finished yet.");
            });
    
            it('revert because not enough balance to withdraw', async function () {
                await this.ico.setIco( false, {from:owner});
                await expectRevert(this.ico.claimTokens({from:investor1}), "ICO.claimTokens: Nothing to claim");
            });
        });
        

        describe.only('claimTokens success', async function () {
            beforeEach(async function () {
                await this.token.transfer(this.ico.address, ONE_HUNDRED_TOKENS, {from: owner});
            });
            it('claimTokens', async function () {
                let currentTime = await time.latest();
                await this.ico.updateUnlockTime(new BN(currentTime.add(new BN('1'))), {from: owner});
                await this.ico.setIco(false, {from: owner});
                await time.increase(new BN('10'));
                currentTime = await time.latest();
                let rewardAmount = await this.ico.unlockedToken(investor1);
                expect(rewardAmount).to.be.bignumber.equal('1000000000000000000');
                await this.ico.claimTokens({from: investor1});
                const balance = await this.token.balanceOf(investor1);
                expect(balance).to.be.bignumber.equal('1000000000000000000');
                rewardAmount = await this.ico.unlockedToken(investor1);
                expect(rewardAmount).to.be.bignumber.equal('0');
            });
            it('claimTokens', async function () {
                await time.increase(new BN('604800'));
                currentTime = await time.latest();
                let rewardAmount = await this.ico.unlockedToken(investor1);
                expect(rewardAmount).to.be.bignumber.equal('0');
            });
            it('claimTokens', async function () {
                await time.increase(new BN('15552000'));
                currentTime = await time.latest();
                let rewardAmount = await this.ico.unlockedToken(investor1);
                expect(rewardAmount).to.be.bignumber.equal('2000000000000000000');
                await this.ico.claimTokens({from: investor1});
                const balance = await this.token.balanceOf(investor1);
                expect(balance).to.be.bignumber.equal('3000000000000000000');
                rewardAmount = await this.ico.unlockedToken(investor1);
                expect(rewardAmount).to.be.bignumber.equal('0');
                const userDetail = await this.ico.userDetails(investor1);
                expect(userDetail.totalRewardAmount).to.be.bignumber.equal('10000000000000000000');
                expect(userDetail.depositAmount).to.be.bignumber.equal('200000000000000');
                expect(userDetail.withdrawAmount).to.be.bignumber.equal('3000000000000000000');
            });
            it('claimTokens', async function () {
                await time.increase(new BN('604800'));
                currentTime = await time.latest();
                let rewardAmount = await this.ico.unlockedToken(investor1);
                expect(rewardAmount).to.be.bignumber.equal('2000000000000000000');
                await this.ico.claimTokens({from: investor1});
                const balance = await this.token.balanceOf(investor1);
                expect(balance).to.be.bignumber.equal('5000000000000000000');
                rewardAmount = await this.ico.unlockedToken(investor1);
                expect(rewardAmount).to.be.bignumber.equal('0');
                const userDetail = await this.ico.userDetails(investor1);
                expect(userDetail.totalRewardAmount).to.be.bignumber.equal('10000000000000000000');
                expect(userDetail.depositAmount).to.be.bignumber.equal('200000000000000');
                expect(userDetail.withdrawAmount).to.be.bignumber.equal('5000000000000000000');
            });
        });
    });
    
});
