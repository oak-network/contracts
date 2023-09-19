import { ethers } from 'hardhat';

export const convertStringToBytes = (val: string) => {

    const {formatBytes32String} = ethers.utils; 
    return formatBytes32String(val);
};

export const convertBytesToString = (val: any) => {
    const { parseBytes32String } = ethers.utils;
    return parseBytes32String(val);
};