// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { CarNFT } from "./CarNFT.sol";

contract Test {
    CarNFT private carNFTContract;

    function leaseCarNFT(
        address carNFTAddress
    ) public {
        CarNFT car = CarNFT(carNFTAddress);
        car.leaseCarNFT(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
        0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, 
        1);

    }
}