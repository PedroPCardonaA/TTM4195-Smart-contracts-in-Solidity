// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CarNFT.sol";
import "./CarStruct.sol";

contract LeaseAgreement {
    address payable public bilBoyd;
    address public alice;
    uint256 public downPayment;
    uint256 public monthlyQuota;
    bool public bilBoydConfirmed;
    CarNFT public carNFTContract;
    
    constructor(
        address payable _bilBoyd,
        uint256 _downPayment,
        uint256 _monthlyQuota,
        address carNFTAddress
    ) {
        bilBoyd = _bilBoyd;
        downPayment = _downPayment;
        monthlyQuota = _monthlyQuota;
        carNFTContract = CarNFT(carNFTAddress); // Reference to CarNFT contract
    }

    function registerDeal() public payable {
        require(msg.value == downPayment + monthlyQuota, "Incorrect payment amount");
        alice = msg.sender;
    }

    function confirmDeal() public {
        require(msg.sender == bilBoyd, "Only BilBoyd can confirm");
        bilBoydConfirmed = true;
        bilBoyd.transfer(downPayment + monthlyQuota);
    }

    function checkForSolvency() public view returns (bool) {
        uint256 balance = alice.balance;
        return balance >= monthlyQuota;
    }

    function terminateLease() public {
        require(msg.sender == alice, "Only Alice can terminate");
        // Logic to terminate the lease
    }

    function extendLease(
        uint256 newContractDuration, 
        uint256 carId, 
        uint8 driverExperienceYears, 
        uint256 mileageCap
    ) public {
        require(msg.sender == alice, "Only Alice can extend");
        // Get the car data from CarNFT contract by accessing each field individually
        Car memory car = carNFTContract.getCarByCarID(carId);
        
        // Now you can access car fields such as car.originalValue, car.mileage, etc.
        // Recompute monthly quota based on new parameters
        monthlyQuota = carNFTContract.calculateMonthlyQuota(
            car.originalValue,
            car.mileage,
            driverExperienceYears,
            mileageCap,
            newContractDuration
        );
    }

    function leaseNewCar(uint256 newCarId) public {
        require(msg.sender == alice, "Only Alice can lease a new car");
        // Transfer new car NFT to Alice
        carNFTContract.safeTransferFrom(bilBoyd, alice, newCarId);
    }
}
