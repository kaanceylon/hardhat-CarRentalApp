// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";




contract CarRentalPlatform is ReentrancyGuard{

    // DATA
   

    // Counter
    using Counters for Counters.Counter;
    Counters.Counter private _counter;
    // ownern
    address public owner;

    // totalPayment
    uint private totalPayments;

    // user struct
    struct User{
    address walletAddress;
    string name;
    string surname;
    uint rentedCarId;
    uint balance;
    uint debt;
    uint start;
    }
   

    // car struct
    struct Car{
        uint id;
        string name;
        string imgUrl;
        Status status;
        uint rentFee;
        uint saleFee;
    }

    // enum to indicate the status of the car
    enum Status {
        Retired,
        InUse,
        Available
    }

    // events
    event CarAdded(uint indexed id, string name, string imgUrl, uint rentFree, uint saleFree);
    event CarMetadataEdited(uint indexed id, string name, string imgUrl, uint rentFree, uint saleFree);
    event CarStatusEdited(uint indexed id, Status status);
    event UserAdded(address indexed walletAddress, string name, string surname);
    event Deposit( address indexed walletAddress, uint amount);
    event CheckOut(address indexed walletAddress, uint carId);
    event CheckIn(address indexed walletAddress, uint amount);
    event PaymentMade(address indexed walletAddress, uint amount);
    event BalancewithDrawn(address indexed walletAddress, uint amount);

    // user mapping
    mapping(address => User) private users;

     // car mapping
    mapping(uint => Car) private cars;

    // constructor
    constructor(){
        owner = msg.sender;
        totalPayments = 0;
    }

    // MODIFIERS
    // Onlyowners
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function.");
        _;
    }

    // FUNCTIONS
    // Execute functions

    //setOwner #Onlyowner
    function setOwner(address _newOwner) external onlyOwner {
        owner = _newOwner;
    }

    // add users #nonexisting
    function addUser(string calldata name, string calldata surname) external {
        require(!isUser(msg.sender), "User already exists"); // if the user in our database  or not
        users[msg.sender] = User(msg.sender, name, surname, 0,0,0,0 );

        emit UserAdded(msg.sender, users[msg.sender].name, users[msg.sender].surname);
    }
    // addCar #OnlyOwner #nonexistingCar
    function addCar(string calldata name, string calldata url, uint rent, uint sale) external onlyOwner {
        _counter.increment();
        uint counter = _counter.current();
        cars[counter] = Car(counter,name,url,Status.Available,rent,sale);

        emit CarAdded(counter,cars[counter].name, cars[counter].imgUrl, cars[counter].rentFee, cars[counter].saleFee);
    }

    // editCar MetaData #OnlyOwner #existingCar
    function editCarMetaData(uint id, string calldata name, string calldata imgUrl, uint rentFee, uint saleFee) external onlyOwner {
        require(cars[id].id != 0, "Car with the given ID does not exist"); // if the car exist or not.
        Car storage car = cars[id]; // we created a storage for this car with the given ID
        if(bytes(name).length !=0){ // we checked parameters if they are empty or not
            car.name = name;
        }
        if(bytes(imgUrl).length !=0){
            car.imgUrl = imgUrl;
        }
        if(rentFee > 0) {
            car.rentFee = rentFee;
        }
        if(saleFee > 0){
            car.saleFee = saleFee;
        }
        emit CarMetadataEdited(id, car.name, car.imgUrl, car.rentFee, car.saleFee);
    }

    // editCarStatus #OnlyOwner  #existingCar
    function editCarStatus(uint id, Status status) external onlyOwner {
        require(cars[id].id !=0, "Car with the given id does not exist");
        cars[id].status = status;

        emit CarStatusEdited(id, status);
    }

    // CheckOut #existingUser #isCarAvailable #userHasNotRentedaCar #userHasNoDebt
    function checkOut(uint id) external {
        require(isUser(msg.sender), "User does not exist"); //checked users
        require(cars[id].status == Status.Available, "Car is not Available for use"); // checked car status
        require(users[msg.sender].rentedCarId == 0, "User has already rented a car"); //if the ID is 0,they didnt rent any car
        require(users[msg.sender].debt == 0, "Users has an outstanding debt!");

        users[msg.sender].start = block.timestamp;
        users[msg.sender].rentedCarId = id; // We are altering the rented car ID of the user
        cars[id].status =  Status.InUse; // Other users would not rent this car beacuse InUse

        emit CheckOut(msg.sender, id);
    }

    // checkIn #exsitingUser #userHasRentACar
    function checkIn() external {
        require(isUser(msg.sender),"User does not exist");
        uint rentedCarId = users[msg.sender].rentedCarId;
        require(rentedCarId !=0, "User has not rented a car");

        uint usedSeconds = block.timestamp - users[msg.sender].start;
        uint rentFee = cars[rentedCarId].rentFee;
        users[msg.sender].debt += calculateDebt(usedSeconds, rentFee);

        users[msg.sender].rentedCarId = 0;
        users[msg.sender].start = 0;
        cars[rentedCarId].status = Status.Available;

        emit CheckIn(msg.sender,rentedCarId);
    }

    // deposit #existingUser
    function deposit()external payable{
        require(isUser(msg.sender),"User does not exist");
        users[msg.sender].balance += msg.value;

        emit Deposit(msg.sender,msg.value);
    }

    // makePayment #existingUser #existingDebt #suffiencientBallance
    function makePayment() external {
        require(isUser(msg.sender),"User does not exist");
        uint debt = users[msg.sender].debt;
        uint balance = users[msg.sender].balance;

        require(debt > 0, "User has no debt to pay");
        require(balance >= debt, "User has insufficient balance");

        unchecked {                 // we unchecked here so solidity wouldn't check the statement. gas free
            users[msg.sender].balance -= debt;
        }
        totalPayments += debt;
        users[msg.sender].debt = 0;

        emit PaymentMade(msg.sender,debt);

    }
    // withDrawBalance #existingUser
    function withDrawBalance(uint amount) external nonReentrant {
        require(isUser(msg.sender), "User does not exist");
        uint balance = users[msg.sender].balance;
        require(balance >= amount, "Insufficient balance to withdraw");

        unchecked {
            users[msg.sender].balance -= amount;
        }

        (bool success, ) = msg.sender.call{value:amount}("");
        require(success, "Transfer failed");
        
        emit BalancewithDrawn(msg.sender, amount);
    }

    // withDrawOwnerBalance #onlyOwner
    function withDrawOwnerBalance(uint amount) external onlyOwner {
        require(totalPayments >= amount, "Insufficient balance to withdraw");

        (bool success, ) = owner.call{value:amount}("");
        require(success, "Transfer failed");

        unchecked {
            totalPayments -= amount;
        }

    }

    // Query Functions

    // getOwner
    function getOwner() external view returns(address){
        return owner;
    }

    // isUser
    function isUser(address walletAddress) private view returns(bool){
        return users[walletAddress].walletAddress != address (0); 
    }

    // getUser #existingUser
    function getUser(address walletAddress) external view returns(User memory){
        require(isUser(walletAddress), "User does not exist");
        return users[walletAddress];
    }

    // getCar #existingCar
    function getCar(uint id) external view returns(Car memory){
        require(cars[id].id != 0, "Car does not exist");
        return cars[id];

    }

    // getCarByStatus 
    function getCarByStatus(Status _status) external view returns(Car[] memory){
        uint count = 0;
        uint lenght = _counter.current();
        for(uint i = 1; i <= lenght; i++){
            if(cars[i].status == _status){ 
                count ++;
            }
        }
        Car[] memory carsWithStatus = new Car [](count);
         count = 0;
        for(uint i = 1; i <= lenght; i++){
            if(cars[i].status == _status){
                carsWithStatus[count] = cars[i];
                count ++;
            }
        }
        return carsWithStatus;
    }

    // calculateDebt
    function calculateDebt(uint usedSeconds, uint rentFee) private pure returns(uint){
        uint usedMinutes = usedSeconds / 60;
        return usedMinutes * rentFee;
    }

    // getCurrentCount
    function getCurrentCount() external view returns(uint){
        return _counter.current();
    }

    // getContractBalance #OnlyOwner // returns the balance of the contract as a whole
    function getContractBalance() external view  onlyOwner returns(uint){
        return address(this).balance;
    }



    // getTotalPayment #onlyOwner // returns payment that are made to the contract
    function getTotalPayment() external view onlyOwner returns(uint){
        return totalPayments;
    } 







}
