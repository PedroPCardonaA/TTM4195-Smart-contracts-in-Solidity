// SPDX-License-Identifier: MIT
/*
ChatGPT:
Recommendations for possible functions
Recommendations were not helpful for solidity in general
Standardization of layouts  for the contracts
*/
pragma solidity ^0.8.0;

import {CarNFT} from "./CarNFT.sol";
import {Car} from "./structs/CarStruct.sol";
import {KeeperCompatibleInterface} from "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

/** @title LeaseAgreement
 *  @notice Implements a lease agreement contract for a car between a company and a customer.
 *  This contract provides functionalities for lease registration, confirmation, monthly payments, termination, and extension
 *  of the contract. The contract utilizes Chainlink Keepers for automated upkeep checks.
 *  @dev The contract uses the CarNFT contract for managing the car NFTs and enforcing ownership.
 */
contract LeaseAgreement is KeeperCompatibleInterface {

    // Address of the company that's issuing the lease
    address payable private immutable company;

    // The customer that is leasing. In our case, it's Alice.
    address payable private immutable customer;

    // Is interpreted as a deposit and will be returned when the contract is terminated
    uint256 private downPayment;

    // What the customer pays monthly
    uint256 private monthlyQuota;

    // Time of deployment of this contract
    uint256 private deployTime;

    // The time when the deal got registered
    uint256 private dealRegistrationTime;

    // Deadline for deal registration
    uint256 private registrationDeadline;

    // Time when the deal was confirmed by the company
    uint256 private confirmDate;

    // Next expected payment date for the customer
    uint256 private nextPaymentDate;

    // Status flag for monthly quota payment
    bool private paidMonthlyQuota;

    // Using arrays instead of enums to reduce complexity
    uint16[4] private contractDurationOptions = [1, 3, 6, 12];
    uint16[8] private mileageCapOptions = [3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000];

    // Chosen contract duration for the current lease
    uint16 private contractDuration;

    // Mileage cap for the lease
    uint16 private mileageCap;

    // Flags for company confirmation, extension, and termination status
    bool private companyConfirmed;
    bool private extended;
    bool private terminated;

    // Reference to the CarNFT contract
    CarNFT private carNFTContract;

    // Details of the car being leased
    Car private carNFT;
    uint256 private carId;

    /// @notice Event emitted when Ether is received
    event EtherReceived(address indexed sender, uint256 amount);

    /// @notice Modifier to ensure that only the company can perform certain actions
    modifier onlyOwner() {
        require(msg.sender == company, "LeaseAgreement: Only the owner-company can perform this action");
        _;
    }

    /// @notice Modifier to ensure that the contract is not terminated
    modifier notTerminated() {
        require(!terminated, "LeaseAgreement: Contract terminated");
        _;
    }

    /// @notice Modifier to ensure that only the customer can perform certain actions
    modifier onlyCustomer() {
        require(msg.sender == customer, "LeaseAgreement: Only customer can modify lease");
        _;
    }

    /// @notice Modifier to ensure that the contract is in the last month of the lease
    modifier isLastMonth() {
        require(contractDuration == 0, "LeaseAgreement: Must wait until last month to terminate lease");
        _;
    }

    /**
     * @notice Creates a new lease agreement for a car between a company and a customer.
     * @dev The contract is deployed by the company, and the car NFT is transferred to the company.
     * @param carNFTAddress The address of the CarNFT contract
     * @param _carID The ID of the car NFT
     * @param _driverExperienceYears The number of years of driving experience of the customer
     * @param _newContractDurationIndex The index of the selected contract duration
     * @param _mileageCapIndex The index of the selected mileage cap
     * @param _company The address of the company that is leasing the car
     * @param _customer The address of the customer
     */
    constructor(
        address carNFTAddress,
        uint256 _carID,
        uint8 _driverExperienceYears,
        uint8 _newContractDurationIndex,
        uint8 _mileageCapIndex,
        address _company,
        address _customer
    ) {
        deployTime = block.timestamp;
        registrationDeadline = 7 days; // TODO: Adjust as needed
        company = payable(_company);
        customer = payable(_customer);
        carNFTContract = CarNFT(payable(carNFTAddress));
        carNFT = carNFTContract.getCarByCarID(_carID);
        carId = _carID;

        require(company == carNFTContract.checkCurrentCarNFTOwner(_carID), "LeaseAgreement: Car already leased");
        require(carNFTContract.availableCarNFT(carId), "LeaseAgreement: Car already reserved");

        contractDuration = getOptionsChoice(_newContractDurationIndex, contractDurationOptions);
        mileageCap = getOptionsChoice(_mileageCapIndex, mileageCapOptions);

        monthlyQuota = carNFTContract.calculateMonthlyQuota(
            carNFT.originalValue,
            carNFT.mileage,
            _driverExperienceYears,
            mileageCap,
            contractDuration
        );
        extended = false;
        terminated = false;

        downPayment = monthlyQuota * 3;
    }

    /**
     * @notice Receive function to handle plain Ether transfers (without data)
     * @dev This function is called when Ether is sent to the contract with empty calldata
     */
    receive() external payable {
        emit EtherReceived(msg.sender, msg.value);
        // Ether is automatically added to the contract's balance
    }

    /**
     * @notice Fallback function that is called when an invalid function is invoked
     * @dev This function accepts Ether sent to the contract with data
     *      It reverts if no Ether is sent along with the invalid function call
     */
    fallback() external payable {
        if (msg.value == 0) {
            revert("LeaseAgreement: Unrecognized function call without Ether");
        }
        emit EtherReceived(msg.sender, msg.value);
        // Ether is automatically added to the contract's balance
    }

    /**
     * @notice Checks if the contract needs upkeep.
     * @dev The contract needs upkeep if the deal registration deadline has passed or if the customer has not paid their monthly quota on time.
     */
    function checkUpkeep(bytes calldata /* checkData */)
        external
        view
        override
        notTerminated
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        if (dealRegistrationTime != 0 && (block.timestamp - dealRegistrationTime) > registrationDeadline) {
            upkeepNeeded = true;
        }

        if (companyConfirmed && block.timestamp >= nextPaymentDate) {
            upkeepNeeded = true;
        }
    }

    /**
     * @notice Performs the upkeep of the lease agreement.
     * @dev If the deal registration deadline has passed, the customer's payment is transferred back to them.
     */
    function performUpkeep(bytes calldata /* performData */) external override notTerminated {
        if (dealRegistrationTime != 0 && (block.timestamp - dealRegistrationTime) > registrationDeadline) {
            customer.transfer(downPayment + monthlyQuota);
            dealRegistrationTime = 0;
        } else if (contractDuration == 0) {
            executeTermination();
        } else if (companyConfirmed && block.timestamp >= nextPaymentDate && !paidMonthlyQuota) {
            // The customer has not paid their quota on time:
            if (extended || !checkForSolvency()) {
                executeTermination();
            } else {
                nextPaymentDate += 10 days;
                extended = true;
                monthlyQuota += (monthlyQuota / 10); // Increase by 10%
            }
        } else if (companyConfirmed && block.timestamp >= nextPaymentDate && paidMonthlyQuota) {
            // The customer has paid their quota on time:
            if (extended) {
                nextPaymentDate += 20 days;
                extended = false;
            } else {
                nextPaymentDate += 30 days;
            }
            contractDuration -= 1;
            paidMonthlyQuota = false;
        }
    }

    /**
     * @notice Registers a new lease agreement between the company and the customer.
     * @dev The customer must pay the down payment and the first monthly quota to register the deal.
     */
    function registerDeal() public payable notTerminated {
        require(deployTime + 2 weeks >= block.timestamp, "LeaseAgreement: The deadline ran out");
        require(msg.value >= downPayment + monthlyQuota, "LeaseAgreement: Incorrect payment amount");
        carNFTContract.reserve(carId);
        dealRegistrationTime = block.timestamp;
        uint256 difference = msg.value - (downPayment + monthlyQuota);
        if (difference > 0) {
            customer.transfer(difference);
        }
    }

    /**
     * @notice Confirms the lease agreement by the company.
     * @dev The company confirms the deal and transfers the first monthly quota to themselves.
     * It is assumed that the customer is retrieving the car the next day,
     * and can pay for the next period in the next 30 days.
     */
    function confirmDeal() public notTerminated onlyOwner {
        companyConfirmed = true;
        company.transfer(monthlyQuota);
        confirmDate = block.timestamp;
        nextPaymentDate = confirmDate + 31 days;
        paidMonthlyQuota = false;
        carNFTContract.leaseCarNFT(
            getCustomer(),
            getCompany(),
            getCarId()
        );
        contractDuration -= 1;
    }

    /**
     * @notice Pays the monthly quota for the lease agreement.
     * @dev The customer pays the monthly quota to the contract. If the payment is higher than the monthly quota,
     * the excess amount is returned to the customer.
     */
    function payMonthlyQuota() public payable notTerminated {
        require(msg.sender == customer, "LeaseAgreement: Only customer can pay");
        require(msg.value >= monthlyQuota, "LeaseAgreement: Payment is too low");
        require(!paidMonthlyQuota, "LeaseAgreement: Lease already paid for");

        uint256 difference = msg.value - monthlyQuota;

        if (difference > 0) {
            customer.transfer(difference);
        }

        paidMonthlyQuota = true;
    }

    /**
     * @notice Terminates the lease agreement.
     * @dev The customer can only terminate the lease agreement at the end of the contract duration
     * after the last monthly payment has been made.
     */
    function terminateLease() public notTerminated isLastMonth onlyCustomer {
        executeTermination();
    }

    /**
     * @notice Extends the lease agreement with new parameters.
     * @dev The customer can extend the lease agreement with new parameters such as contract duration, driver experience years, and mileage cap.
     * @param _extendedContractDurationIndex The index of the new contract duration
     * @param _extendedContractMileageCapIndex The index of the new mileage cap
     * @param _milesTotal The number of miles expended by the customer
     * @param _driverExperienceYears The number of years of driving experience of the customer
     */
    function extendLease(
        uint8 _extendedContractDurationIndex,
        uint8 _extendedContractMileageCapIndex,
        uint256 _milesTotal,
        uint8 _driverExperienceYears
    ) public notTerminated onlyCustomer isLastMonth {
        Car memory car = carNFTContract.getCarByCarID(getCarId());
        require(
            _milesTotal >= car.mileage,
            "LeaseAgreement: The new mileage-total must be greater than or equal to the previous"
        );

        carNFTContract.setMileage(carId, _milesTotal);

        contractDuration = getOptionsChoice(_extendedContractDurationIndex, contractDurationOptions);
        mileageCap = getOptionsChoice(_extendedContractMileageCapIndex, mileageCapOptions);

        // Recompute monthly quota based on new parameters
        monthlyQuota = carNFTContract.calculateMonthlyQuota(
            car.originalValue,
            _milesTotal,
            _driverExperienceYears,
            mileageCap,
            contractDuration
        );

        extended = false;
        terminated = false;
    }

    /**
     * @notice Create a new lease after the old one with a new car.
     * @dev The customer can extend the lease agreement with new parameters such as contract duration, driver experience years, and mileage cap.
     * @param _carID The ID of the new car
     * @param _driverExperienceYears Years of driving experience of the driver
     * @param _newContractDurationIndex The index of the new contract duration
     * @param _mileageCapIndex The index of the new mileage cap duration
    */
    function leaseNewCar(
        uint256 _carID,
        uint8 _driverExperienceYears,
        uint8 _newContractDurationIndex,
        uint8 _mileageCapIndex
    ) public notTerminated onlyCustomer isLastMonth {
        company.transfer(downPayment);
        company.transfer(checkContractValue());
        carNFTContract.returnCarNFT(carId);

        deployTime = block.timestamp;
        registrationDeadline = 7 days;
        carNFT = carNFTContract.getCarByCarID(_carID);
        carId = _carID;

        require(company == carNFTContract.checkCurrentCarNFTOwner(_carID), "LeaseAgreement: Car already leased");
        require(carNFTContract.availableCarNFT(carId), "LeaseAgreement: Car already reserved");

        contractDuration = getOptionsChoice(_newContractDurationIndex, contractDurationOptions);
        mileageCap = getOptionsChoice(_mileageCapIndex, mileageCapOptions);

        monthlyQuota = carNFTContract.calculateMonthlyQuota(
            carNFT.originalValue,
            carNFT.mileage,
            _driverExperienceYears,
            mileageCap,
            contractDuration
        );

        extended = false;
        terminated = false;
        downPayment = monthlyQuota * 3;
        dealRegistrationTime = 0;
    }

    /// @notice Getter for company
    function getCompany() public view returns (address payable) {
        return company;
    }

    /// @notice Getter for customer
    function getCustomer() public view returns (address payable) {
        return customer;
    }

    /// @notice Getter for downPayment
    function getDownPayment() public view returns (uint256) {
        return downPayment;
    }

    /// @notice Getter for monthlyQuota
    function getMonthlyQuota() public view returns (uint256) {
        return monthlyQuota;
    }

    /// @notice Getter for companyConfirmed
    function isCompanyConfirmed() public view returns (bool) {
        return companyConfirmed;
    }

    /// @notice Getter for carNFTContract
    function getCarNFTContract() public view returns (CarNFT) {
        return carNFTContract;
    }

    /// @notice Getter for the car ID
    function getCarId() public view returns (uint256) {
        return carId;
    }

    /// @notice Getter for carNFT
    function getCarNFT() public view returns (Car memory) {
        return carNFT;
    }

    /// @notice Gets the balance of the contract
    function checkContractValue() public view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Getter for contractDuration
    function getContractDuration() public view returns (uint16) {
        return contractDuration;
    }

    /// @notice Getter for mileageCap
    function getContractMileageCap() public view returns (uint16) {
        return mileageCap;
    }

    /**
     * @notice Executes the termination process of the lease agreement.
     * @dev Transfers the remaining contract balance and the car NFT to the company.
     * This function is protected by the `notTerminated` modifier to ensure it cannot be executed if the contract is already terminated.
     */
    function executeTermination() private notTerminated {
        company.transfer(downPayment);
        company.transfer(checkContractValue());
        carNFTContract.returnCarNFT(carId);
        terminated = true;
    }

    /**
     * @notice Checks if the customer has enough balance to pay the monthly quota.
     * @dev The customer is considered solvent if their balance is at least 110% of the monthly quota.
     */
    function checkForSolvency() private view returns (bool) {
        uint256 balance = customer.balance;
        return balance >= monthlyQuota + (monthlyQuota / 10);
    }

    /**
     * @notice Returns the selected option from the available choices in an array.
     * @param _index The index of the selected option
     * @param array The array of available choices
     */
    function getOptionsChoice(uint8 _index, uint16[8] memory array) private pure returns (uint16) {
        require(_index < array.length, "LeaseAgreement: Invalid choice for mileage cap");
        return array[_index];
    }

    /**
     * @notice Returns the selected option from the available choices in an array.
     * @param _index The index of the selected option
     * @param array The array of available choices
     */
    function getOptionsChoice(uint8 _index, uint16[4] memory array) private pure returns (uint16) {
        require(_index < array.length, "LeaseAgreement: Invalid choice for contract duration");
        return array[_index];
    }
}
