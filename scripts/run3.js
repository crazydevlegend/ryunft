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

const NFT_ADDRESS = "0xAdaA1Edf584B35aBeaCA06eA69A415D2Fa82F66e";
const TOKEN_ADDRESS = "0xa8fb68893Bbf0730c54fA67f7c3911E1bc32cA8B";
const STAKING_ADDRESS = "0x13250A43E09C868c63c94144Ab14c385b6f8c23c";

const NFT_ABI = readAbi("Ryu_V2")
const TOKEN_ABI = readAbi("RyuToken")
const STAKING_ABI = readAbi("RyuNFTStaking")


const infuraProvider = new ethers.providers.InfuraProvider("rinkeby", "https://rinkeby.infura.io/v3/c6e0872a300648ec9f7d1e54791d1050")
const signer = ethers.getSigner();
// console.log(await signer.getBalance())

const provider = new ethers.providers.JsonRpcProvider("https://rinkeby-light.eth.linkpool.io/")
const wallet = new ethers.Wallet(process.env.PK, provider);

const nftContract = new ethers.Contract(NFT_ADDRESS, NFT_ABI, wallet)
const tokenContract = new ethers.Contract(TOKEN_ADDRESS, TOKEN_ABI, wallet)
const stakingContract = new ethers.Contract(STAKING_ADDRESS, STAKING_ABI, wallet)


const main = async () => {
    await stakingContract.flipPauseStatus();
    return;
    let tx = await nftContract.toggleEarlyClaimability()
    await tx.wait();
    tx = await nftContract.earlyMint(3, {
        value: ethers.utils.parseEther('0.05')
    })
    await tx.wait();
    console.log(await nftContract.balanceOf(wallet.getAddress()))
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
