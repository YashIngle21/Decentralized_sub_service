// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

error InsufficientFunds(uint256 price, uint256 price_provided);

contract Decentralized_sub_service{

    struct plan{
        uint256 price;
        uint32 duration;
        address provider;
    }

    // uint32 private id_counter;

    mapping (uint64 => plan) public Plans;
    mapping (address => uint256) private subscribers;

    function creatPlan(uint32 id, uint256 _price, uint32 _duration) external {
        Plans[id] = plan(_price, _duration, msg.sender);
    }

    function subscribe(uint64 planId) external payable {
        if(msg.value < Plans[planId].price){
            revert InsufficientFunds(Plans[planId].price, msg.value);
        }
        subscribers[msg.sender] =block.timestamp + Plans[planId].duration;
    }

    function renew(uint64 planId) external payable {
        if(msg.value < Plans[planId].price){
            revert InsufficientFunds(Plans[planId].price, msg.value);
        }
        subscribers[msg.sender] = subscribers[msg.sender] + Plans[planId].duration;
    }

    function isActive() external view returns(bool){
        if(subscribers[msg.sender] > block.timestamp){
            return true;
        }else{
            return false;
        }
    }

    function withdrawFunds() external {
        
    }
    
}