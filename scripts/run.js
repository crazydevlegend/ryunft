const axios = require("axios");
const base64json = require('base64json');
const { upgrades, ethers } = require('hardhat');
const fs = require('fs');
const readAbi = (contract) => {
    let rawdata = fs.readFileSync(`./artifacts/contracts/${contract}.sol/${contract}.json`)
    let abi = JSON.parse(rawdata)
    return abi.abi;
}

const NFT_ADDRESS = "0x3F0f1CE31e2481f8Daf8940dc2Bd6800da566a79";
const TOKEN_ADDRESS = "0x7Cf1d24708D36F8BD1442Cb6319E66969228BA4c";
const STAKING_ADDRESS = "0x33e07178b23871bE12A810e2E3162B47438D656C";

const NFT_ABI = readAbi("Ryu_V2")
const TOKEN_ABI = readAbi("RyuToken")
const STAKING_ABI = readAbi("RyuNFTStaking")


const infuraProvider = new ethers.providers.InfuraProvider("rinkeby", "https://rinkeby.infura.io/v3/c6e0872a300648ec9f7d1e54791d1050")
const signer = await ethers.getSigner();
// console.log(await signer.getBalance())

const provider = new ethers.providers.JsonRpcProvider("https://rinkeby-light.eth.linkpool.io/")

const nftContract = new ethers.Contract(NFT_ADDRESS, NFT_ABI, signer)
const tokenContract = new ethers.Contract(TOKEN_ADDRESS, TOKEN_ABI, signer)
const stakingContract = new ethers.Contract(STAKING_ADDRESS, STAKING_ABI, signer)


const main = async () => {
    // console.log(await ethers.getSigner())

};

const stake = async (tokenId) => {
    let tx = await nftContract.approve(stakingContract.address, tokenId);
    await tx.wait();
    tx = await stakingContract.stake(tokenId);
    await tx.wait();
}
const unstake = async (tokenId) => {

}

const claim = async (tokenId) => {

}

const stakeAll = async () => {
    let tx = await nftContract.approveForAll(stakingContract.address);
    await tx.wait();
    tx = await stakingContract.stake();
    await tx.wait();
}

const unstakeAll = async () => {

}

const claimAll = async () => {

}

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
