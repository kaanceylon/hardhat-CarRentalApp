const {expect, assert} = require("chai");
const {solidity } =require ("ethereum-waffle");
const { ethers} = require("hardhat");

describe("CarRentalPlatform contract test", function () {
  let carRentalPlatform, accounts;
  
 

  const owner = accounts[0];
  const user1 = accounts[1];

  before("deploy the contract instance first",  async function () {
    const CarRentalPlatform = await ethers.getContractFactory("CarRentalPlatform");
    carRentalPlatform = await CarRentalPlatform.deploy ();
    await carRentalPlatform.deploy();
  });

  describe("Add user and car", async () =>{
    await carRentalPlatform.addUser("Alice", "Smith", {from: user1});
    const user = await carRentalPlatform.getUser(user1);
    assert.equal(user.name, "Alice", "Problem with user name" );
    assert.equal(user.surname, "Smith", "Problem with user surname");
});

it("add a car", async () => {
  await carRentalPlatform.addCar("Tesla Model S", "example url", 10, 5000, {from: owner});
  const car = await carRentalPlatform.getCar(1);
  assert.equal(car.name, "Tesla Model S", "Problem with user name" );
  assert.equal(car.imgUrl, "example url", "Problem with img url");
  assert.equal(car.rentFee, 10, "Problem with rent fee");
  assert.equal(car.saleFee, 5000, "Problem with the sale fee");
});
});

describe("Check out and check in car", () => {
  it("Check out a car", async () => {
    await carRentalPlatform.addUser("Alice","Smith", {from: user1});
    await carRentalPlatform.addCar ("Tesla Model S", "example url", 10, 5000, {from:owner});
    await carRentalPlatform.checkOut(1, {from: user1});

    const user = await carRentalPlatform.getUser(user1);
    assert.equal(user.rentedCarId, 1, "User could not check out the car");
  });


it("checks in a car", async() => {
  await carRentalPlatform.addUser("Alice", "Smith", {from: user1});
  await carRentalPlatform.addCar ("Tesla Model S", "example url", 10,5000, {from: owner});
  await carRentalPlatform.checkOut (1, {from: user1 });
  await new Promise ((resolve) => setTimeout(resolve, 6000)); // 1 min

  await carRentalPlatform.checkIn ( {from: user1 });

  const user = await carRentalPlatform.getUser(user1);

  assert.equal(user.rentedCarId, 0, "User could not check in the car");
  assert.equal(user.debt, 10, " User debt did not get created");

  });
});

describe("Deposit token and make payment", () => {
  it ("deposit token", async () => {
    await carRentalPlatform.addUser("Alice", "Smith", {from: user1});
    await carRentalPlatform.deposit({from: user1, value: 100});
    const user = await carRentalPlatform.getUser(user1);
    assert.equal(user.balance, 100, "User could not deposite tokens");


  });

  it ("makes a payment", async () =>{
    await carRentalPlatform.addUser("Alice", "Smith", {from: user1});
    await carRentalPlatform.addCar("Tesla Model S", "example url", 10, 5000, {from: owner});
    await carRentalPlatform.checkOut(1, {from: user1 });
    await new Promise((resolve) => setTimeout(resolve, 6000)); // 1min 
    await carRentalPlatform.checkIn({ from: user1});

    await carRentalPlatform.deposit({from: user1, value: 100});
    await carRentalPlatform.makePayment({ from: user1});
    const user = await carRentalPlatform.getUser(user1);

    assert.equal(user.debt, 0, " Something went wrong while trying to make the payment");
  });
});

describe("edit car", () =>  {
  it("should edit an existing car's metadata with vaild parameters", async () => {
    await carRentalPlatform.addCar ("Tesla Model S", "example url", 10, 5000, {from: owner});

    const newName ="Honda";
    const newImgUrl = "new img url";
    const newRentFee = "20";
    const newSaleFee = "10000";
    await carRentalPlatform.editCarMetaData(1, newName, newImhUrl, newRentFee, newSalefee, {from: owner});

    const car = await carRentalPlatform.getCar(1);
    assert.equal(car.name, newName, "Proble editing car name");
    assert.equal(car.imgUrl, newImgUrl, "Problem updating the image url");
    assert.equal(car.rentFee, newRentFee, "Problem editing rentfee");
    assert.equal(car.saleFee, newSaleFee, "Problem with editing sale fee");

  });

  it("should edit an existing car's status", async () => {
    await carRentalPlatform.addCar("Tesla Model S", "example img url", 10, 5000, {from: owner});
    const newStatus = 0;
    await carRentalPlatform.editCarStatus(1, newStatus, {from: owner});
    const car  = await carRentalPlatform.getCar(1);
    assert.equal(car.status, newStatus, "Problem with editing car status");
  });
});

describe("Withdraw balance", () =>{
  it("should send the desired amount of tokens to the users", async () => {
    await carRentalPlatform.addUser("Alice", "Smith", {from: user1});
    await carRentalPlatform.deposit({from: user1, value:100});
    await carRentalPlatform.withDrawBalance(50, {from: user1});

    const user = await carRentalPlatform.getUser(user1);
    assert.equal(user.balance, 50, "User could not get her tokens");
  });

  it("should send the desired amount of tokens to the owner", async () => {
    await carRentalPlatform.addUser("Alice", "Smith", {from: user1});
    await carRentalPlatform.addCar(" Tesla Model S", "example img url ", 20, 5000, {from: owner});
    await carRentalPlatform.checkOut (1, {from: user1});
    await new Promise((resolve) => setTimeout(resolve, 60000));  // 1 min
    await carRentalPlatform.checkIn ( {from: user1});
    await carRentalPlatform.deposit ( {from: user1, value:1000});
    await carRentalPlatform.makePayment ({from: user1});


    const totalPaymentAmount = await carRentalPlatform.getTotalPayments ({from: owner});
    const amountToWithDraw = totalPaymentAmount - 10;
    await carRentalPlatform.withDrawBalance(amountToWithDraw, {from: owner});
    const totalPayment = await carRentalPlatform.getTotalPayments({from: owner});
    assert.equal(totalPayment, 10, "Owner could not withdraw tokens");

  });

});



