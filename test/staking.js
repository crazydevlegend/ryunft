const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("Staking", function () {
    let nftContract, tokenContract, stakingContract;
    let deployer, otherAccnt;

    beforeEach(async () => {
        [deployer, otherAccnt] = await ethers.getSigners()
    });

    // should deploy nft, token, staking contract
    it("Should deploy nft, token, staking contract", async function () {
        const nftContractFactory = await hre.ethers.getContractFactory('Ryu');
        nftContract = await upgrades.deployProxy(nftContractFactory, [deployer.address, deployer.address], { kind: 'uups', initializer: 'initialize' })
        await nftContract.deployed();

        const tokenContractFactory = await ethers.getContractFactory("RyuToken");
        tokenContract = await tokenContractFactory.deploy();
        await tokenContract.deployed();

        const stakingContractFactory = await ethers.getContractFactory("RyuNFTStaking");
        stakingContract = await stakingContractFactory.deploy(nftContract.address, tokenContract.address);
        await stakingContract.deployed();
        expect(await stakingContract.nft()).to.be.equal(nftContract.address, "wrong nft address");
        expect(await stakingContract.ryuToken()).to.be.equal(tokenContract.address, "wrong token address");
        await tokenContract.setStakingAddress(stakingContract.address);
    });

    // Should mint several nfts
    it("Should mint several nfts", async () => {
        await nftContract.toggleEarlyClaimability()

        await nftContract.earlyMint(3, {
            value: ethers.utils.parseEther('0.05')
        })

        expect(await nftContract.balanceOf(deployer.address)).to.be.equal(3)
    })
    // Should update the token NFT, check if the data is still same
    it("Should update the nft contract", async () => {
        const nft2ContractFactory = await hre.ethers.getContractFactory("Ryu_V2");
        nftContract = await upgrades.upgradeProxy(nftContract.address, nft2ContractFactory, {});
        expect(await nftContract.balanceOf(deployer.address)).to.be.equal(3)
        console.log(`tokenContract ${tokenContract.address} \nnftContract ${nftContract.address}\nstakingContract ${stakingContract.address}`)

    })
    // Should set legendary list
    it("Should set Legendary list", async () => {
        await nftContract.setLegends([0]);
        expect(await nftContract.isLegend(0)).to.be.equal(true);
        expect(await nftContract.isLegend(1)).to.be.equal(false);
        expect(await nftContract.isLegend(2)).to.be.equal(false);

    })
    // Should stake one nft
    it("Should stake one nft", async () => {
        // stake token id 0
        await stakingContract.flipPauseStatus();
        await nftContract.approve(stakingContract.address, 0)

        let tx = await stakingContract.stake(0);
        // check stakes of token 0 is not undefined and staked status is teu
        expect((await stakingContract.stakes(0)).staked).to.be.equal(true)
        expect((await stakingContract.stakes(1)).staked).to.be.equal(false)
        expect((await stakingContract.stakes(2)).staked).to.be.equal(false)

    })


    // should claim reward
    it('Should claim reward', async () => {
        expect((await tokenContract.balanceOf(deployer.address)).toString()).to.be.equal("0")
        await stakingContract.claim(0, false);
        expect((await tokenContract.balanceOf(deployer.address)).toString()).to.not.be.equal("0")
        console.log("balance", (await tokenContract.balanceOf(deployer.address)).toString())

    })
    // should unstake
    // should get all staked nfts 
    it('Should return all staked nfts', async () => {
        const stakedNfts = await stakingContract.getStakedNftsOfOwner(deployer.address);

        expect(stakedNfts).to.have.lengthOf(1);
    })
    // should get all staked nfts 
    it('Should return all unstaked nfts', async () => {
        const stakedNfts = await stakingContract.getUnstakedNftsOfOwner(deployer.address);
        expect(stakedNfts).to.have.lengthOf(2);
    })

    // should unstake nft 
    it('Should unstake nft', async () => {
        expect(await nftContract.balanceOf(deployer.address)).to.be.equal(2);
        await stakingContract.claim(0, true);
        expect(await nftContract.balanceOf(deployer.address)).to.be.equal(3);
    })

    // should stake all nfts
    it('Should stake all nfts', async () => {
        expect(await nftContract.balanceOf(deployer.address)).to.be.equal(3);
        expect(await stakingContract.getStakedNftsOfOwner(deployer.address)).to.have.lengthOf(0);
        await nftContract.setApprovalForAll(stakingContract.address, true);
        await stakingContract.stakeAll();
        expect(await nftContract.balanceOf(deployer.address)).to.be.equal(0);
        expect(await stakingContract.getStakedNftsOfOwner(deployer.address)).to.have.lengthOf(3);

    })


    // should unstake all nfts
    it('Should unstake all nfts', async () => {
        const originalBalance = await tokenContract.balanceOf(deployer.address);

        expect(await nftContract.balanceOf(deployer.address)).to.be.equal(0);
        expect(await stakingContract.getStakedNftsOfOwner(deployer.address)).to.have.lengthOf(3);

        await stakingContract.claimAll(true);
        expect(await nftContract.balanceOf(deployer.address)).to.be.equal(3);
        expect(await stakingContract.getStakedNftsOfOwner(deployer.address)).to.have.lengthOf(0);
        expect(await tokenContract.balanceOf(deployer.address)).to.not.be.equal(originalBalance);

    })
});
