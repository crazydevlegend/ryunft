const axios = require("axios");
const base64json = require('base64json');
const { upgrades, ethers } = require('hardhat');
const fs = require('fs');
const dotenv = require('dotenv')
dotenv.config();
const readAbi = (contract) => {
    let rawdata = fs.readFileSync(`./artifacts/contracts/${contract}.sol/${contract}.json`)
    let abi = JSON.parse(rawdata)
    return abi.abi;
}

const TOKEN_ADDRESS = "0x62e3b272f728A21DE996672D56b8dFE3B59E0CC9";
const NFT_ADDRESS = "0x2ca0507d72e3d30badea3d3b558103d192026251";
const STAKING_ADDRESS = "0xEF239B6AD970D93691Fd3BbF0fE0c49b80144830";

const NFT_ABI = readAbi("Ryu_V2")
const TOKEN_ABI = readAbi("RyuToken")
const STAKING_ABI = readAbi("RyuNFTStaking")


const signer = ethers.getSigner();
// console.log(await signer.getBalance())

const provider = new ethers.providers.JsonRpcProvider("https://speedy-nodes-nyc.moralis.io/e33bb9e9f973ece33adc88f0/avalanche/mainnet")
const wallet = new ethers.Wallet(process.env.PK, provider);

const nftContract = new ethers.Contract(NFT_ADDRESS, NFT_ABI, wallet)
// const tokenContract = new ethers.Contract(TOKEN_ADDRESS, TOKEN_ABI, wallet)
// const stakingContract = new ethers.Contract(STAKING_ADDRESS, STAKING_ABI, wallet)


const main = async () => {

    console.log("balance", await nftContract.balanceOf(await wallet.getAddress()))
    // const stakingContractFactory = await ethers.getContractFactory("RyuNFTStaking");
    // let stakingContract = await stakingContractFactory.deploy(NFT_ADDRESS, TOKEN_ADDRESS);
    // await stakingContract.deployed();
    // console.log(stakingContract.address);
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
