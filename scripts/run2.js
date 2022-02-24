const main = async () => {
    let nftContract, tokenContract, stakingContract;
    let deployer, otherAccnt;

    [deployer] = await ethers.getSigners()

    const nftContractFactory = await hre.ethers.getContractFactory('Ryu');
    nftContract = await upgrades.deployProxy(nftContractFactory, [deployer.address, deployer.address], { kind: 'uups', initializer: 'initialize' })

    const tokenContractFactory = await ethers.getContractFactory("RyuToken");
    tokenContract = await tokenContractFactory.deploy();

    const stakingContractFactory = await ethers.getContractFactory("RyuNFTStaking");
    stakingContract = await stakingContractFactory.deploy(nftContract.address, tokenContract.address, deployer.address);

    await nftContract.deployed();
    console.log(`nftContract: ${nftContract.address}`)

    await tokenContract.deployed();
    console.log(`tokenContract: ${tokenContract.address}`)

    await stakingContract.deployed();
    console.log(`stakingContract: ${stakingContract.address}`)

    let tx = await tokenContract.setStakingAddress(stakingContract.address);
    await tx.wait();

    tx = await nftContract.flipPauseStatus();
    await tx.wait();

    // const nft2ContractFactory = await hre.ethers.getContractFactory("Ryu_V2");
    // nftContract = await upgrades.upgradeProxy(nftContract.address, nft2ContractFactory, {});
    // console.log(`nft Contract: ${nftContract.address}\ntokenContract: ${tokenContract.address}\nstakingContract: ${stakingContract.address}`)

};



const runMain = async () => {
    try {
        await main();
        process.exit(0);
    } catch (error) {
        console.log(error);
        process.exit(1);
    }
};

runMain();