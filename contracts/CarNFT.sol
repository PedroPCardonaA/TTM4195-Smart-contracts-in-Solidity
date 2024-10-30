// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import { Car } from "./structs/CarStruct.sol";

contract CarNFT is ERC721{

    address private owner;
    mapping(uint256 => Car) private cars;
    uint256 private currentSupply;

    modifier onlyOwner() {
        require(msg.sender == owner, "CarNFT: Only the contract owner can mint new NFT"); 
        _;
    }

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
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
        _safeMint(owner, tokenId);
    }

    function leaseCarNFT(
        address toCustomer, 
        address company, 
        uint256 carId
    ) public onlyOwner {
        require(_ownerOf(carId) == company, "CarNFT: Car already leased"); //TODO: reflect on which methods were available to use 
        transferFrom(company, toCustomer, carId);
    }

    function returnCarNFT(uint256 carId) external {
        transferFrom(_ownerOf(carId), owner, carId);
    }

    function calculateMonthlyQuota(
        uint256 originalValue, // in wei
        uint256 currentMileage,
        uint8 driverExperienceYears,
        uint256 mileageCap,
        uint256 contractDuration
    ) external pure returns (uint128) {
        uint256 baseRate = (originalValue + mileageCap );
        uint256 mileageDiscont;
        if (currentMileage < 1000) {
            mileageDiscont = 0;
        } else if (currentMileage < 10000) {
            mileageDiscont = originalValue * 1/20; // 5% discount
        } else {
            mileageDiscont = originalValue * 1/5; // 20% disount
        }
        //uint256 mileageDiscont = currentMileage / mileageCap; 
        uint256 experienceFactor = driverExperienceYears > 5 ? 0 : baseRate * 3/100;
        uint256 durationDiscount;
        if (contractDuration < 7) {
            
        }

        uint128 quota = uint128(baseRate - mileageDiscont + experienceFactor + durationDiscount);
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

    function setMileage(uint256 carId, uint256 _mileage) public validCarId(carId) onlyOwner returns(uint256){
        require(_mileage >= 0, "CarNFT: Mileage cannot be negative");
        cars[carId].mileage = _mileage;
        return cars[carId].mileage;
    }
    
}
