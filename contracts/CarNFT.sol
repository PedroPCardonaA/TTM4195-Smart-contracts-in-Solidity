// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./structs/CarStruct.sol";

contract CarNFT is ERC721, Ownable {

    mapping(uint256 => Car) private cars;
    uint256 private currentSupply;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) Ownable(msg.sender) {
        currentSupply = 0;
    }

    function mintCarNFT(
        string memory model,
        string memory color,
        uint16 yearOfMatriculation,
        uint256 originalValue,
        uint256 mileage
    ) public onlyOwner {
        require(bytes(model).length > 0, "Car model cannot be empty");
        require(bytes(color).length > 0, "Car color cannot be empty");
        require(yearOfMatriculation >= 1886 && yearOfMatriculation <= uint16(block.timestamp / 31556926 + 1970) +1, "Invalid year of matriculation");
        require(originalValue > 0, "Original value must be greater than zero");
        require(mileage >= 0, "Mileage cannot be negative");
        currentSupply += 1;
        uint256 tokenId = currentSupply; 
        cars[tokenId] = Car(model, color, yearOfMatriculation, originalValue, mileage);
        _safeMint(owner(), tokenId);
    }

    function leaseCarNFT(
        address toCustomer, 
        address company, 
        uint256 carId
    ) public onlyOwner {
        require(_ownerOf(carId) == company, "CarNFT: Car already leased"); //TODO: reflect on which methods were available to use 
        transferFrom(company, toCustomer, carId);
    }

    function calculateMonthlyQuota(
        uint256 originalValue,
        uint256 currentMileage,
        uint8 driverExperienceYears,
        uint256 mileageCap,
        uint256 contractDuration
    ) external pure returns (uint256) {
        uint256 baseRate = originalValue / 100; 
        uint256 mileageFactor = currentMileage / mileageCap; 
        uint256 experienceFactor = driverExperienceYears > 5 ? 10 : 20; 
        uint256 durationFactor = contractDuration / 12;

        uint256 quota = baseRate + mileageFactor + experienceFactor + durationFactor;
        return quota;
    }

    function returnCarNFT(uint256 _carId, address customer, address company) public {
        transferFrom(customer, company, _carId);
    }

    modifier validCarId(uint256 carId) { //TODO: util?
         require(carId <= this.getCurrentSupply(), "CarNFT: Car does not exist"); 
        _;
    }

    function getCarByCarID(uint256 carId) public validCarId(carId) view returns (Car memory) {
        return cars[carId];  
    }

    function getCurrentSupply() public view returns (uint256) {
        return currentSupply;
    }

    function checkCurrentCarNFTOwner(uint256 carId) public validCarId(carId) view  returns (address) {
        return _ownerOf(carId);  
    }

    function setMileage(uint256 carId, uint256 _mileage) public validCarId(carId) onlyOwner returns(uint256){
        require(_mileage >= 0, "Mileage cannot be negative");
        cars[carId].mileage = _mileage;
        return cars[carId].mileage;
    }
    
}
