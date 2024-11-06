// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CarNFT.sol";
import "./LeaseAgreement.sol";

/**
 * @title BilBoydController
 * @notice The BilBoydController is the main contract to manage the lifecycle of the cars and lease agreements.
 * It allows minting new car NFTs, creating lease agreements, and terminating them.
 * @dev The contract is owned and managed by the creator (company), enabling functions for car management.
 */
contract BilBoydController {
    // CarNFT contract
    CarNFT public carNFT;

    // Owner of this contract
    address public owner;

    // Lease object to store all lease agreements
    struct Lease {
        uint256 carId;
        address leaseContractAddress;
        bool isActive;
    }

    // Mapping with lease agreements for each car ID
    mapping(uint256 => Lease) public leases;

    // Counter to keep track of the amount of lease agreements
    uint256 public leaseCounter;

    // Event to log the creation of a new lease agreement
    event LeaseCreated(uint256 carId, address leaseContractAddress, address lessee);

    /// @notice Modifier to check if the caller is the owner of the contract
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
