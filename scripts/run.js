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
const STAKING_ADDRESS = "0xdfC8e2Fc57EEcD41DcACf1847DC7D5B13652D37D";

const NFT_ABI = readAbi("Ryu_V2")
const TOKEN_ABI = readAbi("RyuToken")
const STAKING_ABI = readAbi("RyuNFTStaking")


const infuraProvider = new ethers.providers.InfuraProvider("rinkeby", "https://rinkeby.infura.io/v3/c6e0872a300648ec9f7d1e54791d1050")
const signer = ethers.getSigner();
// console.log(await signer.getBalance())

const provider = new ethers.providers.JsonRpcProvider("https://api.avax-test.network/ext/bc/C/rpc")
const wallet = new ethers.Wallet(process.env.PK, provider);

const nftContract = new ethers.Contract(NFT_ADDRESS, NFT_ABI, wallet)
const tokenContract = new ethers.Contract(TOKEN_ADDRESS, TOKEN_ABI, wallet)
const stakingContract = new ethers.Contract(STAKING_ADDRESS, STAKING_ABI, wallet)


const main = async () => {
    // await stakingContract.flipPauseStatus();
    // let tx = await nftContract.toggleEarlyClaimability()
    // await tx.wait();
    // tx = await nftContract.earlyMint(3, {
    //     value: ethers.utils.parseEther('0.05')
    // })
    // await tx.wait();
    // console.log("owner", await wallet.getBalance());
    // return;
    console.log("Balance", (await nftContract.owner()));
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
