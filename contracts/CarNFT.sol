// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import {Car} from "./structs/CarStruct.sol";

/**
 * @title CarNFT
 * @notice The NFT is represented as a ERC721 token representing individual cars with attributes and ownership.
 * This contract allows minting, leasing, returning, and updating car NFTs
 * @dev The contract is owned and managed by the creator, enabling functions for car lifecycle management
 */
contract CarNFT is ERC721 {
    // Owner of the contract
    address private owner;

    // Mapping with car data for each token ID
    mapping(uint256 => Car) private cars;

    // Mapping carId to availability boolean
    mapping(uint256 => bool) private availability;

    // Mapping with lease agreements for each token ID
    mapping(uint256 => address) public leaseAgreements;

    // Counter to keep track of the amount of token cars
    uint256 private currentSupply;

    /// @notice Modifier to check if the caller is the owner of the contract
    modifier onlyOwner() {
        require(msg.sender == owner, "CarNFT: You need to be owner");
        _;
    }

    /// @notice Modifier to approve a client to lease a car. Only the owner can approve
    function giveApprovement(address client, uint256 carID) public onlyOwner {
        approve(client, carID);
    }

    /**
     * @notice Initializes a new CarNFT contract with a name and symbol
     * @param name The ERC721 name
     * @param symbol The ERC721 symbol
     */
    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        owner = msg.sender;
        currentSupply = 0;
    }

    /**
     * @notice Mints a new car NFT
     * @dev Only the contract owner can mint new cars
     * @param model The model of the car
     * @param color The color of the car
     * @param yearOfMatriculation The year the car was registered, must be within a realistic range
     * @param originalValue The original value of the car in wei
     * @param mileage The initial mileage of the car
     */
    function mintCarNFT(
        string memory model,
        string memory color,
        uint16 yearOfMatriculation,
        uint128 originalValue,
        uint32 mileage
    ) public onlyOwner {
        require(bytes(model).length > 0, "CarNFT: Model cannot be empty");
        require(bytes(color).length > 0, "CarNFT: Color cannot be empty");
        require(
            yearOfMatriculation >= 1886 &&
                yearOfMatriculation <=
                uint256(block.timestamp / 31556926 + 1970) + 1,
            "CarNFT: Invalid year of matriculation"
        );
        require(originalValue > 0, "CarNFT: Original value must be greater than zero");
        require(mileage >= 0, "CarNFT: Mileage cannot be negative");
        currentSupply += 1;
        uint256 tokenId = currentSupply;
        cars[tokenId] = Car(
            model,
            color,
            yearOfMatriculation,
            originalValue,
            mileage
        );
        availability[tokenId] = true;
        _mint(owner, tokenId);
    }

    /**
     * @notice Reserve a car by its id, but only if it is available.
     * @dev Set the corresponding availability boolean to false.
     * @param carId: ID of the car to lease
    */
    function reserve(uint256 carId) external validCarId(carId) {
        require(availability[carId], "This car isn't available for lease");
        availability[carId] = false;
    }

    /**
     * @notice Get the availability of a car.
     * @param carId: ID of the car to lease.
     * @return whether the car is available to lease.
    */
    function availableCarNFT(uint256 carId) external view validCarId(carId) returns (bool) {
        return availability[carId];
    }

    /**
     * @notice Leases a car NFT to a customer by transferring ownership from the company to the customer.
     * @dev Only the owner (company) can initiate the leasing. The car must not be already leased.
     * @param toCustomer Address of the customer leasing the car
     * @param company Address of the current car owner
     * @param carId ID of the car to lease
     */
    function leaseCarNFT(
        address toCustomer,
        address company,
        uint256 carId
    ) public {
        require(_ownerOf(carId) == company, "CarNFT: Car already leased");
        transferFrom(company, toCustomer, carId);
        leaseAgreements[carId] = msg.sender;
    }

    /**
     * @notice Returns a leased car NFT back to the company.
     * @param carId ID of the car being returned
     */
    function returnCarNFT(uint256 carId) external {
    require(leaseAgreements[carId] == msg.sender, "CarNFT: Only the associated LeaseAgreement can return the car");
        _transfer(_ownerOf(carId), owner, carId);
        leaseAgreements[carId] = address(0);
        availability[carId] = true;
    }

    /**
     * @notice Calculates the monthly lease quota based on various factors
     * @param originalValue The original value of the car in wei
     * @param currentMileage The car's current mileage
     * @param driverExperienceYears Years of driving experience of the customer
     * @param mileageCap Mileage cap for the lease contract
     * @param contractDuration Duration of the lease contract in months
     * @return The calculated monthly quota for the lease
     */
    function calculateMonthlyQuota(
        uint256 originalValue,
        uint256 currentMileage,
        uint8 driverExperienceYears,
        uint256 mileageCap,
        uint256 contractDuration
    ) external pure returns (uint128) {
        uint256 mileageDiscont;
        uint256 baseRate = originalValue / 100;
        if (currentMileage < 1000) {
            mileageDiscont = 0;
        } else if (currentMileage < 10000) {
            mileageDiscont = (baseRate * 5) / 100;
        } else {
            mileageDiscont = (baseRate * 20) / 100;
        }
        uint256 experienceFactor = driverExperienceYears > 5 ? 0 : (baseRate * 3) / 100;
        uint256 durationDiscount;
        if (contractDuration > 10) {
            durationDiscount = (baseRate * 3) / 100;
        } else if (contractDuration > 5) {
            durationDiscount = (baseRate * 2) / 100;
        } else if (contractDuration > 2) {
            durationDiscount = (baseRate * 1) / 100;
        } else {
            durationDiscount = 0;
        }

        uint256 mileageFee;
        if (mileageCap > 9000) {
            mileageFee = (baseRate * 5) / 100;
        } else if (mileageCap > 6000) {
            mileageFee = (baseRate * 3) / 100;
        } else if (mileageCap > 3000) {
            mileageFee = (baseRate * 2) / 100;
        } else {
            mileageFee = 0;
        }

        uint128 quota = uint128(baseRate - mileageDiscont + experienceFactor - durationDiscount + mileageFee);
        return quota;
    }

    /**
     * @notice Modifier to validate that the car ID already exists in the system.
     * @param carId ID of the car to validate
     */
    modifier validCarId(uint256 carId) {
        //TODO: util?
        require(carId <= this.getCurrentSupply(), "CarNFT: Car does not exist");
        _;
    }

    /**
     * @notice Retrieves car data for a specific car ID.
     * @param carId ID of the car to retrieve data for
     * @return Car struct containing the car's attributes
     */
    function getCarByCarID(
        uint256 carId
    ) public view validCarId(carId) returns (Car memory) {
        return cars[carId];
    }

    /**
     * @notice Retrieves the owner of the contract.
     */
    function getOwner() public view returns (address) {
        return owner;
    }

    /**
     * @notice Retrieves the number of minted cars in the system.
     * @return The current supply count
     */
    function getCurrentSupply() public view returns (uint256) {
        return currentSupply;
    }

    /**
     * @notice Checks the current owner of a car NFT by car ID.
     * @param carId ID of the car to check ownership for
     * @return Address of the current owner of the car
     */
    function checkCurrentCarNFTOwner(
        uint256 carId
    ) public view validCarId(carId) returns (address) {
        return _ownerOf(carId);
    }

    /**
     * @notice Sets the mileage for a specific car.
     * @dev Only the owner can set the mileage.
     * @param carId ID of the car to update mileage for
     * @param _mileage The new mileage value to set
     * @return The updated mileage of the car
     */
    function setMileage(uint256 carId, uint256 _mileage) public validCarId(carId) returns(uint256){
        require(_mileage >= 0, "CarNFT: Mileage cannot be negative");
        require(msg.sender == owner || leaseAgreements[carId] == msg.sender,"CarNFT: Only the associated LeaseAgreement can update mileages");
        cars[carId].mileage = _mileage;
        return cars[carId].mileage;
    }
}
