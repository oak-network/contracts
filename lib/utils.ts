import { ethers } from "hardhat";

export const hexString = (val: string) => {
const { hexlify, toUtf8Bytes, hexZeroPad } = ethers.utils;
    return hexZeroPad(hexlify(toUtf8Bytes(val)), 32);
};

export const hashString = (val: string) => {
    return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(val));
}
