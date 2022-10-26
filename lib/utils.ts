import { ethers } from "hardhat";

export const getHexString = (val: string) => {
const { hexlify, toUtf8Bytes, hexZeroPad } = ethers.utils;
    return hexZeroPad(hexlify(toUtf8Bytes(val)), 32);
};
