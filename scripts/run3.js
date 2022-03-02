const { upgrades, ethers } = require('hardhat');



const main = async () => {
    let nftContract, tokenContract, stakingContract;
    let deployer, otherAccnt;

    [deployer] = await ethers.getSigners()


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