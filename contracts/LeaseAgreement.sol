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
    uint256 private confirmDate;
    uint256 private nextPaymentDate;
    bool private paidMonthlyQuota;
    uint256 private contractDuration;
    bool private bilBoydConfirmed;
    bool private extended;
    bool private terminated;
    CarNFT private carNFTContract;
    Car private carNFT;
    uint256 private carId;
    
    // It is possible to get _monthlyQuota by using contract CarNFT?
    constructor(
        address carNFTAddress,
        uint256 _carID,
        uint8 _driverExperienceYears,
        uint256 _mileageCap, //TODO: check that mileage is higher than what is in the car
        uint256 _newContractDuration
    ) {
        deployTime = block.timestamp;
        registrationDeadline = 10 seconds; //TODO: Change to x weeks
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
        contractDuration = _newContractDuration;
        extended = false;
        terminated = false;


        downPayment = monthlyQuota * 3;
    }

    modifier onlyOwner() { //TODO: util?
        require(msg.sender == bilBoyd, "LeaseAgreement: Only the owner-company can perform this action");
        _;
    }

    modifier notTerminated() {
        require(!terminated, "LeaseAgreement: Contract terminated");
        _;
    }

    function checkUpkeep(bytes calldata /* checkData */) external view notTerminated override returns (bool upkeepNeeded, bytes memory /* performData */) {
        if (dealRegistrationTime != 0 && (block.timestamp - dealRegistrationTime) > registrationDeadline) {
            upkeepNeeded = true;
        }

        if (bilBoydConfirmed && block.timestamp >= nextPaymentDate) {
            upkeepNeeded = true;
        }

    }

    function performUpkeep(bytes calldata /* performData */) external notTerminated override {
        if (dealRegistrationTime != 0 && (block.timestamp - dealRegistrationTime) > registrationDeadline) {
            customer.transfer(downPayment + monthlyQuota);
            dealRegistrationTime = 0;
        }

        else if (bilBoydConfirmed && block.timestamp >= nextPaymentDate && !paidMonthlyQuota) {
            // The customer has not paid their quota on time:

            if (extended || !checkForSolvency()) {
                executeTermination();
            } else {
                nextPaymentDate += 10 days;
                extended = true;
                monthlyQuota += (monthlyQuota / 10); // Increase by 10%
            }
        }

        else if (bilBoydConfirmed && block.timestamp >= nextPaymentDate && paidMonthlyQuota) {

            if(extended) {
                nextPaymentDate += 20 days; 
                extended = false;
            }
            else {
                nextPaymentDate += 30 days; 
            }
            paidMonthlyQuota = false; 
            //Evt: pay to bilboyd from contract
        }

    }

    function executeTermination() private notTerminated {
        bilBoyd.transfer(this.checkContractValue());
        carNFTContract.returnCarNFT(carId);
        terminated = true;
    }

    // Used by the customer to register their deal offer
    function registerDeal() public notTerminated payable {
        require(deployTime + 2 weeks >= block.timestamp, "LeaseAgreement: The deadline ran out");
        require(msg.value >= downPayment + monthlyQuota, "LeaseAgreement: Incorrect payment amount");
        dealRegistrationTime = block.timestamp;
        uint256 difference = msg.value - (downPayment + monthlyQuota);  //TODO: helper
        customer = payable(msg.sender);
        customer.transfer(difference);
    }

    // Used by the company to confirm that the customer's deal is accepted by the company
    function confirmDeal() public notTerminated onlyOwner {
        bilBoydConfirmed = true;
        bilBoyd.transfer(downPayment + monthlyQuota);
        confirmDate = block.timestamp;
        nextPaymentDate = confirmDate + 31 days; // It is assumed that the customer is retrieving the car the next day, 
        //and can pay for the next period in the next 30 days after that
        paidMonthlyQuota = false;
        carNFTContract.leaseCarNFT(this.getCustomer(), this.getBilBoyd(), this.getCarId());
    }

    function checkForSolvency() private view notTerminated returns (bool) {
        uint256 balance = customer.balance;
        return balance >= monthlyQuota + (monthlyQuota / 10);
    }

    function payMonthlyQuota() public notTerminated payable {
        require(msg.sender == customer, "LeaseAgreement: Only customer can pay"); // Ensure that the customer is the one who is paying
        require(msg.value >= monthlyQuota, "LeaseAgreement: Payment is too low");
        require(!paidMonthlyQuota, "LeaseAgreement: Lease already paid for");

        uint256 difference = msg.value - monthlyQuota;

        if(msg.value > monthlyQuota) {
            customer.transfer(difference);
        }

        paidMonthlyQuota = true; 
    }

    function terminateLease() public notTerminated {
        require(msg.sender == customer, "LeaseAgreement: Only customer can terminate");
        executeTermination();
    }

    function extendLease (
        uint256 newContractDuration, 
        uint8 driverExperienceYears, 
        uint256 mileageCap
    ) public notTerminated onlyOwner {
        require(msg.sender == customer, "LeaseAgreement: Only customer can extend");
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

    function leaseNewCar(uint256 newCarId) public notTerminated {
        require(msg.sender == customer, "LeaseAgreement: Only customer can lease a new car");
        // Transfer new car NFT to Alice
        carNFTContract.safeTransferFrom(bilBoyd, customer, newCarId); //Can use leaseCarNFT
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

    function checkContractValue() public view returns (uint256) {
        return address(this).balance;
    }

}
