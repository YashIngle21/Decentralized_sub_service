// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Decentralized_sub_service{
    struct plan{
        uint256 price;
        uint32 duration;
        string provider;
    }

    mapping (uint64 => plan) public plans;
    mapping (address => uint256) private subscribers;

    function creatPlan(uint256 price, uint32 duration) external {

    }

    function subscribe(uint64 planId) external payable {}

    function renew(uint64 planId) external payable {}

    function isActive() external {}

    function withdrawFunds() external {}
    
}