async function deployWithProxy(web3, contractABI, contractBytecode, proxyABI, proxyBytecode, initParams, proxyAdmin, deploymentConfig) {
    let data;
    if(initParams) {
        data = web3.eth.abi.encodeFunctionCall(contractABI.initialize, initParams);
    } else {
        data = ""
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

module.exports = {
    deployWithProxy,
    deployContract
}