// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import { Car } from "./structs/CarStruct.sol";

contract CarNFT is ERC721{

    address private owner;
    mapping(uint256 => Car) private cars;
    mapping(uint256 => address) public leaseAgreements;
    uint256 private currentSupply;

    modifier onlyOwner() {
        require(msg.sender == owner, "CarNFT: You need to be owner"); 
        _;
    }

    function giveApprovement(address client, uint256 carID) public onlyOwner {
        approve(client, carID);
    }

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        owner = msg.sender;
        currentSupply = 0;
    }

    function mintCarNFT(
        string memory model,
        string memory color,
        uint16 yearOfMatriculation,
        uint128 originalValue, // in wei
        uint32 mileage
    ) public onlyOwner {
        require(bytes(model).length > 0, "CarNFT: Model cannot be empty");
        require(bytes(color).length > 0, "CarNFT: Color cannot be empty");
        require(yearOfMatriculation >= 1886 && yearOfMatriculation <= uint256(block.timestamp / 31556926 + 1970) +1, "CarNFT: Invalid year of matriculation");
        require(originalValue > 0, "CarNFT: Original value must be greater than zero");
        require(mileage >= 0, "CarNFT: Mileage cannot be negative");
        currentSupply += 1;
        uint256 tokenId = currentSupply; 
        cars[tokenId] = Car(model, color, yearOfMatriculation, originalValue, mileage);
        _mint(owner, tokenId);
    }

    function leaseCarNFT(
        address toCustomer, 
        address company, 
        uint256 carId
    ) public /* onlyOwner*/ {
        require(_ownerOf(carId) == company, "CarNFT: Car already leased"); //TODO: reflect on which methods were available to use 
        transferFrom(company, toCustomer, carId);
        leaseAgreements[carId] = msg.sender;
    }


    function returnCarNFT(uint256 carId) external {
    require(leaseAgreements[carId] == msg.sender, "CarNFT: Only the associated LeaseAgreement can return the car");
        _transfer(_ownerOf(carId), owner, carId);
        leaseAgreements[carId] = address(0);
    }

    function calculateMonthlyQuota(
        uint256 originalValue, // in wei
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
            mileageDiscont = baseRate * 5/100;
        } else {
            mileageDiscont = baseRate * 20/100;
        }
        uint256 experienceFactor = driverExperienceYears > 5 ? 0 : baseRate * 3/100;
        uint256 durationDiscount;
        if (contractDuration > 10) {
            durationDiscount = baseRate * 3/100 ;
        } else if (contractDuration > 5) {
            durationDiscount = baseRate * 2/100 ;
        } else if (contractDuration > 2) {
            durationDiscount = baseRate * 1/100 ;
        } else {
            durationDiscount = 0;
        }

        uint256 mileageFee;
        if (mileageCap > 9000) {
            mileageFee = baseRate * 5/100 ;
        } else if (mileageCap > 6000) {
            mileageFee = baseRate * 3/100 ;
        } else if (mileageCap > 3000) {
            mileageFee = baseRate * 2/100 ;
        } else {
            mileageFee = 0;
        }
        
        uint128 quota = uint128(baseRate - mileageDiscont + experienceFactor - durationDiscount + mileageFee);
        return quota;
    }

    modifier validCarId(uint256 carId) { //TODO: util?
         require(carId <= this.getCurrentSupply(), "CarNFT: Car does not exist"); 
        _;
    }

    function getCarByCarID(uint256 carId) public validCarId(carId) view returns (Car memory) {
        return cars[carId];  
    }

    function getOwner() public view returns (address) {
        return owner;
    }

    function getCurrentSupply() public view returns (uint256) {
        return currentSupply;
    }

    function checkCurrentCarNFTOwner(uint256 carId) public validCarId(carId) view  returns (address) {
        return _ownerOf(carId);  
    }

    function setMileage(uint256 carId, uint256 _mileage) public validCarId(carId) onlyOwner returns(uint256){
        require(_mileage >= 0, "CarNFT: Mileage cannot be negative");
        cars[carId].mileage = _mileage;
        return cars[carId].mileage;
    }
    
}
