// SPDX-License-Identifier: MIT
/*
ChatGPT:
Recommendations for possible functions
Recommendations were not helpful for solidity in general
Standardization of layouts  for the contracts
*/
pragma solidity ^0.8.0;

import "remix_tests.sol"; // Import the Remix testing library
import "remix_accounts.sol";
import "../contracts/CarNFT.sol";
import "../contracts/structs/CarStruct.sol";

contract CarNFTTest {
    CarNFT carNFT;
    address leasingCompany = address(this);
    address customer = TestsAccounts.getAccount(0);
    address otherAccount = TestsAccounts.getAccount(1);
    //address leasingCompany = TestsAccounts.getAccount(1);

    function beforeEach() public {
        carNFT = new CarNFT("CarNFT", "CNFT");
        Assert.equal(carNFT.getOwner(), leasingCompany, "Owner should be set correctly at deployment");
        carNFT.mintCarNFT("Tesla Model S", "Red", 2020, 1000, 5000);
    }

    function testMintCarNFT() public {
        Car memory car = carNFT.getCarByCarID(1);
        Assert.equal(car.model, "Tesla Model S", "Model should be Tesla Model S");
        Assert.equal(car.color, "Red", "Color should be Red");
        Assert.equal(car.yearOfMatriculation, 2020, "Year of matriculation should be 2020");
        Assert.equal(car.mileage, 5000, "Mileage should be 5000");
    }

    function testSetMileage() public {
        carNFT.mintCarNFT("Ford Mustang", "Yellow", 2021, 1200000000000000000, 0);
        uint256 updatedMileage = carNFT.setMileage(1, 15000);
        Assert.equal(updatedMileage, 15000, "Mileage should be updated to 15000");
    }

    function testInvalidCarID() public {
        try carNFT.getCarByCarID(999) {
            Assert.ok(false, "Getting a car with an invalid ID should revert");
        } catch Error(string memory reason) {
            Assert.equal(reason, "CarNFT: Car does not exist", "Expected car existence error");
        }
    }

    function testInvalidYearOfMatriculation() public {
        try carNFT.mintCarNFT("Mercedes-Benz", "Black", 1800, 1000000000000000000, 0) {
            Assert.ok(false, "Minting with invalid year should revert");
        } catch Error(string memory reason) {
            Assert.equal(reason, "CarNFT: Invalid year of matriculation", "Expected invalid year error");
        }
    }

    function testNonPositiveBaseRate() public {
        try carNFT.mintCarNFT("Audi A4", "Red", 2020, 0, 0) {
            Assert.ok(false, "Minting with non-positive base rate should revert");
        } catch Error(string memory reason) {
            Assert.equal(reason, "CarNFT: Original value must be greater than zero", "Expected non-positive base rate error");
        }
    }
}
