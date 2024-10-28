// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CarNFT.sol";
import "./structs/CarStruct.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

contract LeaseAgreement is KeeperCompatibleInterface {
    address payable private immutable bilBoyd; //change to less specific
    address payable private customer; // Alice is our customer
    uint256 private immutable downPayment;
    uint256 private monthlyQuota;
    uint256 private immutable deployTime;
    uint256 private dealRegistrationTime;
    uint256 private registrationDeadline;
    bool private bilBoydConfirmed;
    CarNFT private carNFTContract;
    Car private carNFT;
    uint256 private carId;
    
    // It is possible to get _monthlyQuota by using contract CarNFT?
    constructor(
        address carNFTAddress,
        uint256 _carID,
        uint8 _driverExperienceYears,
        uint256 _mileageCap,
        uint256 _newContractDuration
    ) {
        deployTime = block.timestamp;
        registrationDeadline = 10 seconds;
        bilBoyd = payable(msg.sender); 
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

    function checkUpkeep(bytes calldata /* checkData */) external override returns (bool upkeepNeeded, bytes memory /* performData */) {
        if(dealRegistrationTime == 0) {
            upkeepNeeded = false;
        } 
        else {
            upkeepNeeded = (block.timestamp - dealRegistrationTime) > registrationDeadline;
        }
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        if ((block.timestamp - dealRegistrationTime) > registrationDeadline ) {
            performRefund();
            dealRegistrationTime = 0;
        }
    }

    // Used by the customer to register their deal offer
    function registerDeal() public payable {
        require(msg.value == downPayment + monthlyQuota, "Incorrect payment amount");
        dealRegistrationTime = block.timestamp;
        customer = payable(msg.sender);
    }

    // Used by the company to confirm that the customer's deal is accepted by the company
    function confirmDeal() public onlyOwner {
        bilBoydConfirmed = true;
        bilBoyd.transfer(downPayment + monthlyQuota);
        carNFTContract.leaseCarNFT(this.getCustomer(), this.getBilBoyd(), this.getCarId());
    }

    function performRefund() public onlyOwner {
        customer.transfer(downPayment + monthlyQuota);
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
