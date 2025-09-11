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
error NothingToWithdraw();
error WithdrawFailed();
error RefundFailed();
error AlreadySubed();

contract Decentralized_sub_service{

    /** State variables */
    struct plan{
        uint256 price;
        uint32 duration;
        address  provider;
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
    event PlanSubscribed(address subscriber, uint64 planId, uint256 totalAmountPaid, uint256 startTimeStamp, uint256 expiryTimeStamp);
    event PlanRenewed(address subscriber, uint64 planId, uint256 totalAmountPaid, uint256 startTimeStamp, uint256 expiryTimeStamp);
    event PlanCreated(uint64 planId, uint256 price, uint256 duration, address provider , uint256 providerBalance);
    event PlanUpdated(uint64 planId, uint256 price, uint256 duration, address provider , uint256 providerBalance);
    event FundsWithdrawn(address provider, uint256 amount);

    /** Modifiers*/

    modifier onlyProvider(){
        if(!isProvider[msg.sender]){
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

    function createPlan(uint64 _planId, uint256 _price, uint32 _duration) external planNotExists(_planId){
        if(_duration == 0){
            revert DurationCantBeZero();
        }

        Plans[_planId] = plan(_price, _duration, msg.sender);
        isProvider[msg.sender] = true;

        emit PlanCreated(_planId, _price, _duration, msg.sender,ProviderBalance[msg.sender]);
        
    }

    function updatePlan(uint64 _planId, uint256 _price, uint32 _duration) external planExists(_planId) onlyProvider{
        if(_duration == 0){
            revert DurationCantBeZero();
        }

        Plans[_planId].price = _price;
        Plans[_planId].duration = _duration;

        emit PlanUpdated(_planId, _price, _duration, msg.sender, ProviderBalance[msg.sender]);
    }

    function subscribe(uint64 _planId) external payable planExists(_planId){
        if(msg.value < Plans[_planId].price){
            revert InsufficientFunds(Plans[_planId].price, msg.value);
        }

        if(subscriptions[_planId][msg.sender].expiryTimeStamp > block.timestamp){
            revert AlreadySubed();
        }

        uint256 overpaidAmount = msg.value - Plans[_planId].price;

        
        subscriptions[_planId][msg.sender].startTimeStamp = block.timestamp;
        subscriptions[_planId][msg.sender].expiryTimeStamp = block.timestamp + Plans[_planId].duration;
        subscriptions[_planId][msg.sender].totalAmountPaid  += Plans[_planId].price;
        ProviderBalance[Plans[_planId].provider] += Plans[_planId].price;

        if (overpaidAmount > 0) {
            (bool success, ) = payable(msg.sender).call{value: overpaidAmount}("");
            require(success, RefundFailed());
        }

        emit PlanSubscribed(msg.sender , _planId, subscriptions[_planId][msg.sender].totalAmountPaid, subscriptions[_planId][msg.sender].startTimeStamp, subscriptions[_planId][msg.sender].expiryTimeStamp);

    }

    function renew(uint64 _planId) external payable onlySubscribers(_planId) {
        if(msg.value < Plans[_planId].price){
            revert InsufficientFunds(Plans[_planId].price, msg.value);
        }

        
        subscriptions[_planId][msg.sender].startTimeStamp = block.timestamp > subscriptions[_planId][msg.sender].expiryTimeStamp ? block.timestamp : subscriptions[_planId][msg.sender].startTimeStamp;
        subscriptions[_planId][msg.sender].expiryTimeStamp = block.timestamp > subscriptions[_planId][msg.sender].startTimeStamp ?  block.timestamp + Plans[_planId].duration : subscriptions[_planId][msg.sender].expiryTimeStamp + Plans[_planId].duration;
        subscriptions[_planId][msg.sender].totalAmountPaid  += Plans[_planId].price;
        ProviderBalance[Plans[_planId].provider] += Plans[_planId].price;

        emit PlanRenewed(msg.sender , _planId, subscriptions[_planId][msg.sender].totalAmountPaid, subscriptions[_planId][msg.sender].startTimeStamp, subscriptions[_planId][msg.sender].expiryTimeStamp);
    }

    function isActive(uint64 planId, address user) public view returns(bool){
        if(subscriptions[planId][user].expiryTimeStamp > block.timestamp){
            return true;
        }else{
            return false;
        }
    }

    function isActive(uint64 planId) public view returns(bool){
        if(subscriptions[planId][msg.sender].expiryTimeStamp > block.timestamp){
            return true;
        }else{
            return false;
        }
    }

    function withdrawFunds() external onlyProvider(){
        uint256 amount = ProviderBalance[msg.sender];
        if(amount == 0){
            revert NothingToWithdraw();
        } 
        ProviderBalance[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        
        if(!success){
            ProviderBalance[msg.sender] = amount;
            revert WithdrawFailed();
        }

        emit FundsWithdrawn(msg.sender, amount);
    }
    
}