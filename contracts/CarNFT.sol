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
        address toCompany,
        string memory model,
        string memory color,
        uint16 yearOfMatriculation,
        uint256 originalValue,
        uint256 mileage
    ) public onlyOwner {
        currentSupply += 1;
        uint256 tokenId = currentSupply; 
        cars[tokenId] = Car(model, color, yearOfMatriculation, originalValue, mileage);
        _safeMint(toCompany, tokenId);
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

    
}
