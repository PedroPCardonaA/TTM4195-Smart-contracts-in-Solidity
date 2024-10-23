// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CarNFT.sol";
import "./structs/CarStruct.sol";

contract LeaseAgreement {
    address payable private immutable bilBoyd;
    address private customer; // Alice is our customer
    uint256 private immutable downPayment;
    uint256 private monthlyQuota;
    bool private bilBoydConfirmed;
    CarNFT private carNFTContract;
    Car private carNFT;
    uint256 private carId;
    
    // It is possible to get _monthlyQuota by using contract CarNFT?
    constructor(
        address payable _bilBoyd,
        address carNFTAddress,
        uint256 _carID,
        uint8 _driverExperienceYears,
        uint256 _mileageCap,
        uint256 _newContractDuration
    ) {
        bilBoyd = _bilBoyd; 
        carNFTContract = CarNFT(carNFTAddress); 
        Car memory car = carNFTContract.getCarByCarID(_carID);
        carId = _carID;

        monthlyQuota = carNFTContract.calculateMonthlyQuota(
            car.originalValue,
            car.mileage,
            _driverExperienceYears,
            _mileageCap,
            _newContractDuration
        );

        downPayment = monthlyQuota * 3;
    }

    modifier onlyOwner() { //TODO: util?
        require(msg.sender == bilBoyd, "Only the owner-company can perform this action");
        _;
    }

    function registerDeal() public payable {
        require(msg.value == downPayment + monthlyQuota, "Incorrect payment amount");
        customer = msg.sender;
    }

    function confirmDeal() public onlyOwner {
        bilBoydConfirmed = true;
        bilBoyd.transfer(downPayment + monthlyQuota);
        carNFTContract.leaseCarNFT(this.getCustomer(), this.getBilBoyd(), this.getCarId());
    }

    function checkForSolvency() public view returns (bool) {
        uint256 balance = customer.balance;
        return balance >= monthlyQuota;
    }

    function terminateLease() public view {
        require(msg.sender == customer, "Only customer can terminate");
        // Logic to terminate the lease
    }

    function extendLease (
        uint256 newContractDuration, 
        uint8 driverExperienceYears, 
        uint256 mileageCap
    ) public onlyOwner {
        require(msg.sender == customer, "Only customer can extend");
        // Get the car data from CarNFT contract by accessing each field individually
        Car memory car = carNFTContract.getCarByCarID(this.getCarId());
        
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
        require(msg.sender == customer, "Only customer can lease a new car");
        // Transfer new car NFT to Alice
        carNFTContract.safeTransferFrom(bilBoyd, customer, newCarId);
    }


    // Getter for bilBoyd
    function getBilBoyd() public view returns (address payable) {
        return bilBoyd;
    }

    // Getter for customer (Alice)
    function getCustomer() public view returns (address) {
        return customer;
    }

    // Getter for downPayment
    function getDownPayment() public view returns (uint256) {
        return downPayment;
    }

    // Getter for monthlyQuota
    function getMonthlyQuota() public view returns (uint256) {
        return monthlyQuota;
    }

    // Getter for bilBoydConfirmed
    function isBilBoydConfirmed() public view returns (bool) {
        return bilBoydConfirmed;
    }

    // Getter for carNFTContract
    function getCarNFTContract() public view returns (CarNFT) {
        return carNFTContract;
    }
    
    // Getter for the car id
    function getCarId() public view returns (uint256) {
        return carId;
    }

    // Getter for carNFT
    function getCarNFT() public view returns (Car memory) {
        return carNFT;
    }

}
