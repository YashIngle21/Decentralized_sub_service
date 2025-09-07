// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

error InsufficientFunds(uint256 price, uint256 price_provided);
error NotProvider(address provider);
error PlanNotExists(uint64 planId);

contract Decentralized_sub_service{

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

    // uint32 private id_counter;


    mapping(address=> bool) public isProvider;
    mapping (uint64 => plan) public Plans;
    mapping(uint256 => mapping (address => subscription)) public subscriptions;

    modifier onlyProvider(){
        if(!isProvider[msg.sender]){
            revert NotProvider(msg.sender);
        }
        _;
    }
    modifier planExists(uint64 planId){
        if(Plans[planId].provider == address(0)){
            revert PlanNotExists(planId);
        }
        _;
    }
    function creatPlan(uint32 planId, uint256 _price, uint32 _duration) external planExists(planId){
        Plans[planId] = plan(_price, _duration, msg.sender);
    }

    function subscribe(uint64 planId) external payable {
        if(msg.value < Plans[planId].price){
            revert InsufficientFunds(Plans[planId].price, msg.value);
        }
        
    }

    function renew(uint64 planId) external payable {
        if(msg.value < Plans[planId].price){
            revert InsufficientFunds(Plans[planId].price, msg.value);
        }
        
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