import { ethers } from 'hardhat';

export const convertStringToBytes = (val: string) => {

    const {formatBytes32String} = ethers.utils; 
    return formatBytes32String(val);
};

export const convertBytesToString = (val: any) => {
    const { parseBytes32String } = ethers.utils;
    return parseBytes32String(val);
};

export const splitByteCodeIntoChunks = (byteCode: string, numberOfChunks: number) => {
    const numChunks = Math.ceil(byteCode.length / numberOfChunks)
    const chunks = new Array(numberOfChunks);
    let o = 0;
    for (let i = 0; i < numberOfChunks; i++) {
        if( i !== 0 ) {
            let chunk = byteCode.slice(o, numChunks + o);
            if(chunk.length % 2 === 1){
                chunks[i] = '0x' + byteCode.slice(o, (numChunks + o) - 1 )
                o += numChunks - 1;
            }else{
                chunks[i] = '0x' + byteCode.slice(o, numChunks + o)
                o += numChunks;
            }
            
        }
        else{
            let chunk = byteCode.slice(o, numChunks);
            if(chunk.length % 2 === 1){
                chunks[i] = byteCode.slice(o, numChunks+1);
                o += numChunks + 1;
            }else{
                chunks[i] = byteCode.slice(o, numChunks);
                o += numChunks;
            }
        } 
    }

    return chunks;
}

export const convertBigNumber = (value: number, decimal: number) => {
    return ethers.BigNumber.from(value).mul(ethers.BigNumber.from(10).pow(decimal));
}

export const increaseBlockTime = async (value: number) => {
    return await ethers.provider.send("evm_increaseTime", [value]);
}