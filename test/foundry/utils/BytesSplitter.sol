// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "forge-std/console.sol";

/// @notice Bytes Splitter Contract for spliting bytes.
contract BytesSplitter {

    /**
     * @notice Splits Bytes into two chunks.
     * @param data The bytecode.
     */
    function splitBytesIntoTwo(bytes memory data) public pure returns (bytes memory chunk1, bytes memory chunk2) {
        
      uint midpoint = data.length / 2;
      bytes memory data1 = new bytes(midpoint);
      for (uint i = 0; i < midpoint; i++) {
          data1[i] = data[i];
      }
      bytes memory data2 = new bytes(data.length - midpoint);
      for (uint i = 0; i < data.length - midpoint; i++) {
          data2[i] = data[i + midpoint];
      }

      return (data1, data2);
    }
}
