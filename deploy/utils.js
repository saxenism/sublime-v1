const ethJsUtil = require('ethereumjs-util')

async function deployWithProxy(web3, contractABI, contractBytecode, proxyABI, proxyBytecode, initParams, proxyAdmin, deploymentConfig) {
    let data;
    if (initParams) {
        const initializeABI = getInitializeABI(contractABI);
        data = web3.eth.abi.encodeFunctionCall(initializeABI, initParams);
    } else {
        data = Buffer.from("");
    }
    const contractAddress = await deployContract(
        web3,
        contractABI,
        contractBytecode,
        [],
        deploymentConfig
    );
    const proxyAddress = await deployContract(
        web3,
        proxyABI,
        proxyBytecode,
        [contractAddress, proxyAdmin, data],
        deploymentConfig
    );
    console.log(`Contract: ${contractAddress} , Proxy: ${proxyAddress}`);

    return (await new web3.eth.Contract(contractABI, proxyAddress));
}

function getInitializeABI(abi) {
    let initializeABI;
    for (let i = 0; i < abi.length; i++) {
        if (abi[i].name == "initialize") {
            initializeABI = abi[i];
            break;
        }
    }
    return initializeABI;
}

async function deployContract(web3, abi, bytecode, arguments, config) {
    const contract = new web3.eth.Contract(abi);
    const receiptPromise = new Promise((resolve, reject) => {
        contract.deploy({
            data: bytecode,
            arguments,
        })
            .send(config)
            .on("transactionHash", console.log)
            .on("receipt", (receipt) => {
                resolve(receipt.contractAddress);
            })
            .on("error", (error) => {
                reject(error);
            });
    });
    return receiptPromise;
}

async function addAccounts(web3, keystore) {
    for (let account in keystore) {
        await web3.eth.accounts.wallet.add(keystore[account])
    }
    return web3
}

async function generateAddress(web3, address, toAdd = 0) {
    let transactionCount = await getTransactionCount(web3, address)
    //toAdd - to increase tx count for generating future addresses
    transactionCount += toAdd

    const futureAddress = ethJsUtil.bufferToHex(
        ethJsUtil.generateAddress(address, transactionCount),
    )
    return futureAddress
}

async function getTransactionCount(web3, address) {
    const transactionCount = await web3.eth.getTransactionCount(address)
    return transactionCount
}

module.exports = {
    deployWithProxy,
    deployContract,
    getInitializeABI,
    addAccounts,
    generateAddress,
}