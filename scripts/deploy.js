const main = async () => {
  let nftContract, tokenContract, stakingContract;
  let deployer, otherAccnt;

  [deployer] = await ethers.getSigners()

  const nftContractFactory = await hre.ethers.getContractFactory('Ryu');
  nftContract = await upgrades.deployProxy(nftContractFactory, [deployer.address, deployer.address], { kind: 'uups', initializer: 'initialize' })
  await nftContract.deployed();

  const tokenContractFactory = await ethers.getContractFactory("RyuToken");
  tokenContract = await tokenContractFactory.deploy();
  await tokenContract.deployed();

  // const stakingContractFactory = await ethers.getContractFactory("RyuNFTStaking");
  // stakingContract = await stakingContractFactory.deploy(nftContract.address, tokenContract.address, deployer.address);
  // await stakingContract.deployed();
  // await tokenContract.setStakingAddress(stakingContract.address);

  // const nft2ContractFactory = await hre.ethers.getContractFactory("Ryu_V2");
  // nftContract = await upgrades.upgradeProxy(nftContract.address, nft2ContractFactory, {});


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