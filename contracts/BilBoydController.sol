// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CarNFT.sol";
import "./LeaseAgreement.sol";

contract BilBoydController {
    CarNFT public carNFT;
    address public owner;

    struct Lease {
        uint256 carId;
        address leaseContractAddress;
        bool isActive;
    }

    mapping(uint256 => Lease) public leases;
    uint256 public leaseCounter;

    event LeaseCreated(uint256 carId, address leaseContractAddress, address lessee);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    constructor(address carNFTAddress) {
        carNFT = CarNFT(carNFTAddress); 
        owner = msg.sender;
    }

    function mintCarNFT(
        string memory model,
        string memory color,
        uint16 yearOfMatriculation,
        uint256 originalValue,
        uint256 mileage
    ) public onlyOwner {
        carNFT.mintCarNFT(address(this), model, color, yearOfMatriculation, originalValue, mileage);
    }

    function createLeaseAgreement(
        uint256 carId,
        uint256 downPayment,
        uint256 monthlyQuota,
        uint8 driverExperienceYears,
        uint256 mileageCap,
        uint256 contractDuration
    ) public {
        require(carNFT.ownerOf(carId) == address(this), "BilBoydController must own the car to lease it");

        LeaseAgreement leaseAgreement = new LeaseAgreement(
            payable(owner), 
            downPayment, 
            monthlyQuota, 
            address(carNFT)
        ); //TODO: FIX

        carNFT.safeTransferFrom(address(this), msg.sender, carId);

        leases[carId] = Lease({
            carId: carId,
            leaseContractAddress: address(leaseAgreement),
            isActive: true
        });

        leaseCounter++;

        emit LeaseCreated(carId, address(leaseAgreement), msg.sender);
    }

    function terminateLease(uint256 carId) public onlyOwner {
        require(leases[carId].isActive, "Lease is already inactive");
        leases[carId].isActive = false;
    }
}
