// Layout of the contract file:
// version
// imports
// errors
// interfaces, libraries, contract

// Inside Contract:
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/** Errors */

error InsufficientFunds(uint256 price, uint256 price_provided);
error NotProvider(address provider);
error PlanNotExists(uint64 planId);
error PlanExists(uint64 planId);
error NotSubscribed(address subscriber,uint64 planId);
error DurationCantBeZero();


contract Decentralized_sub_service{

    /** State variables */
    struct plan{
        uint256 price;
        uint32 duration;
        address provider;
    }


    struct subscription{
        uint256 expiryTimeStamp;
        uint256 startTimeStamp;
        uint256 totalAmountPaid;
    }

    mapping(address => uint256) public ProviderBalance;
    mapping(address => bool) public isProvider;
    mapping (uint64 => plan) public Plans;
    mapping(uint64 => mapping (address => subscription)) public subscriptions;


    /** Events */
    event subscribed(address subscriber, uint64 planId, uint256 totalAmountPaid, uint256 startTimeStamp, uint256 expiryTimeStamp);

    /** Modifiers*/

    modifier onlyProvider(){
        if(isProvider[msg.sender]){
            revert NotProvider(msg.sender);
        }
        _;
    }

    modifier planExists(uint64 _planId){
        if(Plans[_planId].provider == address(0)){
            revert PlanNotExists(_planId);
        }
        _;
    }

    modifier planNotExists(uint64 _planId){
        if(!(Plans[_planId].provider == address(0))){
            revert PlanExists(_planId);
        }
        _;
    }

    modifier onlySubscribers(uint64 _planId){
        if(subscriptions[_planId][msg.sender].expiryTimeStamp < block.timestamp){
            revert NotSubscribed(msg.sender, _planId);
        }
        _;
    }


    /** Functions */

    function creatPlan(uint64 _planId, uint256 _price, uint32 _duration) external planNotExists(_planId){
        if(_duration == 0){
            revert DurationCantBeZero();
        }

        Plans[_planId] = plan(_price, _duration, msg.sender);
        ProviderBalance[msg.sender] = 0;
        isProvider[msg.sender] = true;
        
    }

    function subscribe(uint64 _planId) external payable {
        if(msg.value < Plans[_planId].price){
            revert InsufficientFunds(Plans[_planId].price, msg.value);
        }

        subscriptions[_planId][msg.sender].startTimeStamp = block.timestamp;
        subscriptions[_planId][msg.sender].expiryTimeStamp = block.timestamp + Plans[_planId].duration;
        subscriptions[_planId][msg.sender].totalAmountPaid  += Plans[_planId].price;

        emit subscribed(msg.sender , _planId, subscriptions[_planId][msg.sender].totalAmountPaid, subscriptions[_planId][msg.sender].startTimeStamp, subscriptions[_planId][msg.sender].expiryTimeStamp);

    }

    function renew(uint64 _planId) external payable onlySubscribers(_planId) {
        if(msg.value < Plans[_planId].price){
            revert InsufficientFunds(Plans[_planId].price, msg.value);
        }

        subscriptions[_planId][msg.sender].expiryTimeStamp = subscriptions[_planId][msg.sender].startTimeStamp + Plans[_planId].duration;
        subscriptions[_planId][msg.sender].totalAmountPaid  += Plans[_planId].price;

        emit subscribed(msg.sender , _planId, subscriptions[_planId][msg.sender].totalAmountPaid, subscriptions[_planId][msg.sender].startTimeStamp, subscriptions[_planId][msg.sender].expiryTimeStamp);
    }

    function isActive(uint64 planId) external view returns(bool){
        if(subscriptions[planId][msg.sender].expiryTimeStamp > block.timestamp){
            return true;
        }else{
            return false;
        }
    }

    function withdrawFunds() external onlyProvider(){
        
    }
    
}