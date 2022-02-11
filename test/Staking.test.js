const { BN, constants, expectEvent, time, expectRevert, ether, balance } = require('@openzeppelin/test-helpers');
const { ZERO_ADDRESS } = constants;

const { expect } = require('chai');

const ERC20 = artifacts.require('MockERC20');
const Staking = artifacts.require('Staking');


function seconds_since_epoch(){ 
    var d = new Date();
    return Math.floor( d.getTime() / 1000 ); 
}
  

contract('Staking Test', function ([owner, masterWallet, investor1, investor2, investor3]) {

    const name = 'AEL token';
    const symbol = 'AEL';
    const decimal = new BN('18');


    const tokenSupply = new BN('100000000000000000000000000');
    const reward_token = new BN('10000000000000000000000');
    const FIVE_THOUSAND_TOKENS = new BN('5000000000000000000000');
    const TEN_TOKEN = new BN('10000000000000000000');
    const FIVE_TOKENS = new BN('5000000000000000000');
    const TWO_TOKENS = new BN('2000000000000000000');
    const ONE_TOKEN = new BN('1000000000000000000');
    const REMAINING_TOKENS = new BN('99000000000000000000');
    const Thirty_days = new BN('2592000');

    beforeEach(async function () {
        this.token = await ERC20.new(name, symbol, {from: owner});
        this.staking = await Staking.new(this.token.address, masterWallet, {from: owner});
        await this.token.mint(owner, tokenSupply, {from: owner});
        await this.token.transfer(investor1, FIVE_THOUSAND_TOKENS, {from:owner});
        await this.token.transfer(investor2, FIVE_THOUSAND_TOKENS, {from:owner});
        await this.token.transfer(this.staking.address, reward_token, {from:owner});
    });


    describe('Validate', function () {
        describe('pause', function() {
            it('deposit revert because contract paused', async function () {
                await this.staking.pause({from:owner});
                await expectRevert.unspecified(this.staking.deposit(ONE_TOKEN, true, {from:investor1}));
            });
            it('withdraw revert because contract paused', async function () {
                await expectRevert.unspecified(this.staking.withdraw(ONE_TOKEN, {from:investor1}));
            });
        });
    });

    describe('Test', function () {
        describe('Deposit 0.1 AEL TOKEN for a monthly period + withdraw all', async function () {
            
            it('success', async function () {
                // await this.staking.unpause({from:owner});
                let oldBalance = await this.token.balanceOf(investor1);
                await this.token.approve(this.staking.address, new BN('100000000000000000'), {from: investor1});
                await this.staking.deposit(new BN('100000000000000000'), true, {from:investor1});
                let newBalance = await this.token.balanceOf(investor1);
                let changes = new BN(oldBalance.sub(newBalance));
                expect(changes).to.be.bignumber.equal('100000000000000000');

                let deposits = await this.staking.getDeposit(investor1);
                expect(deposits[0]).to.be.bignumber.equal('100000000000000000');
                expect(deposits[1]).to.be.bignumber.equal('0');
                
                await time.increase(new BN('2592099'));
                const rewards = await this.staking.getReward(investor1);
                expect(rewards[0]).to.be.bignumber.equal('2000000000000000');
                expect(rewards[1]).to.be.bignumber.equal('0');
                oldBalance = await this.token.balanceOf(investor1);
                await this.staking.withdraw('100000000000000000', {from: investor1});
                newBalance = await this.token.balanceOf(investor1);
                changes = new BN(newBalance.sub(oldBalance));
                expect(changes).to.be.bignumber.equal('101000000000000000');

                deposits = await this.staking.getDeposit(investor1);
                expect(deposits[0]).to.be.bignumber.equal('0');
                expect(deposits[1]).to.be.bignumber.equal('0');
            });
        });
        
        
        describe('Deposit 0.2 AEL TOKEN for a quarlery period + withdraw all ', async function () {
            
            it('success', async function () {
                let oldBalance = await this.token.balanceOf(investor1);
                await this.token.approve(this.staking.address, new BN('200000000000000000'), {from: investor1});
                await this.staking.deposit(new BN('200000000000000000'), false, {from:investor1});
                let newBalance = await this.token.balanceOf(investor1);
                let changes = new BN(oldBalance.sub(newBalance));
                expect(changes).to.be.bignumber.equal('200000000000000000');

                let deposits = await this.staking.getDeposit(investor1);
                expect(deposits[0]).to.be.bignumber.equal('0');
                expect(deposits[1]).to.be.bignumber.equal('200000000000000000');
                await time.increase(new BN('7776099'));
                const rewards = await this.staking.getReward(investor1);
                expect(rewards[0]).to.be.bignumber.equal('0');
                expect(rewards[1]).to.be.bignumber.equal('20000000000000000');
                oldBalance = await this.token.balanceOf(investor1);
                await this.staking.withdraw('200000000000000000', {from: investor1});
                newBalance = await this.token.balanceOf(investor1);
                changes = new BN(newBalance.sub(oldBalance));
                expect(changes).to.be.bignumber.equal('218000000000000000');

                deposits = await this.staking.getDeposit(investor1);
                expect(deposits[0]).to.be.bignumber.equal('0');
                expect(deposits[1]).to.be.bignumber.equal('0');
            });
        });

        describe('Withdrawing before the first completed month ', async function () {
            
            it('fail', async function () {
                // await this.staking.unpause({from:owner});
                let oldBalance = await this.token.balanceOf(investor1);
                await this.token.approve(this.staking.address, new BN('10000000000000000000'), {from: investor1});
                await this.staking.deposit(new BN('10000000000000000000'), true, {from:investor1});
                let newBalance = await this.token.balanceOf(investor1);
                let changes = new BN(oldBalance.sub(newBalance));
                expect(changes).to.be.bignumber.equal('10000000000000000000');

                let deposits = await this.staking.getDeposit(investor1);
                expect(deposits[0]).to.be.bignumber.equal('10000000000000000000');
                expect(deposits[1]).to.be.bignumber.equal('0');
                
                const rewards = await this.staking.getReward(investor1);
                expect(rewards[0]).to.be.bignumber.equal('0');
                expect(rewards[1]).to.be.bignumber.equal('0');
                await expectRevert(this.staking.withdraw('10000000000000000000', {from: investor1}), "Not enough tokens to withdraw");

                deposits = await this.staking.getDeposit(investor1);
                expect(deposits[0]).to.be.bignumber.equal('10000000000000000000');
                expect(deposits[1]).to.be.bignumber.equal('0');
            });
        });

        describe('Withdrawing before the first completed quarter ', async function () {
            
            it('fail', async function () {
                // await this.staking.unpause({from:owner});
                let oldBalance = await this.token.balanceOf(investor1);
                await this.token.approve(this.staking.address, new BN('50000000000000000000'), {from: investor1});
                await this.staking.deposit(new BN('50000000000000000000'), false, {from:investor1});
                let newBalance = await this.token.balanceOf(investor1);
                let changes = new BN(oldBalance.sub(newBalance));
                expect(changes).to.be.bignumber.equal('50000000000000000000');

                let deposits = await this.staking.getDeposit(investor1);
                expect(deposits[0]).to.be.bignumber.equal('0');
                expect(deposits[1]).to.be.bignumber.equal('50000000000000000000');
                
                const rewards = await this.staking.getReward(investor1);
                expect(rewards[0]).to.be.bignumber.equal('0');
                expect(rewards[1]).to.be.bignumber.equal('0');
                await expectRevert(this.staking.withdraw('50000000000000000000', {from: investor1}), "Not enough tokens to withdraw");

                deposits = await this.staking.getDeposit(investor1);
                expect(deposits[0]).to.be.bignumber.equal('0');
                expect(deposits[1]).to.be.bignumber.equal('50000000000000000000');
            });
        });
        
        describe('Depositing monthly multiple times', async function () {
            
            it('success', async function () {
                // await this.staking.unpause({from:owner});
                let oldBalance = await this.token.balanceOf(investor1);
                await this.token.approve(this.staking.address, new BN('100000000000000000000'), {from: investor1});
                await this.staking.deposit(new BN('100000000000000000000'), true, {from:investor1});
                let newBalance = await this.token.balanceOf(investor1);
                let changes = new BN(oldBalance.sub(newBalance));
                expect(changes).to.be.bignumber.equal('100000000000000000000');

                let deposits = await this.staking.getDeposit(investor1);
                expect(deposits[0]).to.be.bignumber.equal('100000000000000000000');
                expect(deposits[1]).to.be.bignumber.equal('0');
                
                await time.increase(new BN('432001'));
                await this.token.approve(this.staking.address, new BN('200000000000000000000'), {from: investor1});
                await this.staking.deposit(new BN('200000000000000000000'), true, {from:investor1});

                deposits = await this.staking.getDeposit(investor1);
                expect(deposits[0]).to.be.bignumber.equal('300000000000000000000');
                expect(deposits[1]).to.be.bignumber.equal('0');

                await time.increase(new BN('2160001'));
                let rewards = await this.staking.getReward(investor1);
                expect(rewards[0]).to.be.bignumber.equal('2000000000000000000');
                expect(rewards[1]).to.be.bignumber.equal('0');

                await time.increase(new BN('432001'));
                rewards = await this.staking.getReward(investor1);
                expect(rewards[0]).to.be.bignumber.equal('6000000000000000000');
                expect(rewards[1]).to.be.bignumber.equal('0');

                await time.increase(new BN('2160001'));
                rewards = await this.staking.getReward(investor1);
                expect(rewards[0]).to.be.bignumber.equal('8040000000000000000');
                expect(rewards[1]).to.be.bignumber.equal('0');

                await time.increase(new BN('432001'));
                rewards = await this.staking.getReward(investor1);
                expect(rewards[0]).to.be.bignumber.equal('12120000000000000000');
                expect(rewards[1]).to.be.bignumber.equal('0');
            });
        });

        describe('Depositing quarlery multiple times', async function () {
            
            it('success', async function () {
                // await this.staking.unpause({from:owner});
                let oldBalance = await this.token.balanceOf(investor1);
                await this.token.approve(this.staking.address, new BN('300000000000000000000'), {from: investor1});
                await this.staking.deposit(new BN('300000000000000000000'), false, {from:investor1});
                let newBalance = await this.token.balanceOf(investor1);
                let changes = new BN(oldBalance.sub(newBalance));
                expect(changes).to.be.bignumber.equal('300000000000000000000');

                let deposits = await this.staking.getDeposit(investor1);
                expect(deposits[0]).to.be.bignumber.equal('0');
                expect(deposits[1]).to.be.bignumber.equal('300000000000000000000');
                
                await time.increase(new BN('432001'));
                await this.token.approve(this.staking.address, new BN('400000000000000000000'), {from: investor1});
                await this.staking.deposit(new BN('400000000000000000000'), false, {from:investor1});

                deposits = await this.staking.getDeposit(investor1);
                expect(deposits[0]).to.be.bignumber.equal('0');
                expect(deposits[1]).to.be.bignumber.equal('700000000000000000000');

                await time.increase(new BN('7344001'));
                let rewards = await this.staking.getReward(investor1);
                expect(rewards[0]).to.be.bignumber.equal('0');
                expect(rewards[1]).to.be.bignumber.equal('30000000000000000000');

                await time.increase(new BN('432001'));
                rewards = await this.staking.getReward(investor1);
                expect(rewards[0]).to.be.bignumber.equal('0');
                expect(rewards[1]).to.be.bignumber.equal('70000000000000000000');

                await time.increase(new BN('7344001'));
                rewards = await this.staking.getReward(investor1);
                expect(rewards[0]).to.be.bignumber.equal('0');
                expect(rewards[1]).to.be.bignumber.equal('103000000000000000000');

                await time.increase(new BN('432001'));
                rewards = await this.staking.getReward(investor1);
                expect(rewards[0]).to.be.bignumber.equal('0');
                expect(rewards[1]).to.be.bignumber.equal('147000000000000000000');

                await time.increase(new BN('432001'));
                oldBalance = await this.token.balanceOf(investor1);
                await this.staking.withdraw(0, {from:investor1});
                newBalance = await this.token.balanceOf(investor1);
                changes = new BN(newBalance.sub(oldBalance));
                expect(changes).to.be.bignumber.equal('147000000000000000000');

                await time.increase(new BN('432001'));
                rewards = await this.staking.getReward(investor1);
                expect(rewards[0]).to.be.bignumber.equal('0');
                expect(rewards[1]).to.be.bignumber.equal('0');

                await time.increase(new BN('6480001'));
                rewards = await this.staking.getReward(investor1);
                expect(rewards[0]).to.be.bignumber.equal('0');
                expect(rewards[1]).to.be.bignumber.equal('30000000000000000000');

                await time.increase(new BN('432001'));
                rewards = await this.staking.getReward(investor1);
                expect(rewards[0]).to.be.bignumber.equal('0');
                expect(rewards[1]).to.be.bignumber.equal('70000000000000000000');
            });
        });
    });
});
