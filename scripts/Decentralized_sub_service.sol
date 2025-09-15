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
error PlanAlreadyActive();
error NothingToRefund();
error PlanNotActive();


contract Decentralized_sub_service{

    /** State variables */
    struct plan {
        uint256 price;
        uint256 deactivationTimeStamp;
        uint32 duration;
        bool isActive;
        address provider;
    }


    struct subscription{
        uint256 expiryTimeStamp;
        uint256 startTimeStamp;
        uint256 totalAmountPaid;
    }

    struct providerDetails{
        uint64[] planIds;
        uint256 providerBalance;
        bool isProvider; 
    }

    mapping(address => providerDetails) public ProviderPlans;
    mapping (uint64 => plan) public Plans;
    mapping(uint64 => mapping (address => subscription)) public subscriptions;


    /** Events */
    event PlanSubscribed(address subscriber, uint64 planId, uint256 totalAmountPaid, uint256 startTimeStamp, uint256 expiryTimeStamp);
    event PlanRenewed(address subscriber, uint64 planId, uint256 totalAmountPaid, uint256 startTimeStamp, uint256 expiryTimeStamp);
    event PlanCreated(uint64 planId, uint256 price, uint256 duration, address provider , uint256 providerBalance, bool isActive,uint256 deactivationTimeStamp);
    event PlanUpdated(uint64 planId, uint256 price, uint256 duration, address provider , uint256 providerBalance,bool isActive,uint256 deactivationTimeStamp);
    event FundsWithdrawn(address provider, uint256 amount);
    event RefundIssued(uint64 planId, address provider , uint256 overpaidAmount);
    event subscriptionCancelled(uint64 planId, address user, uint256 AmountRefunded);

    /** Modifiers*/

    modifier onlyProvider(){
        if(!ProviderPlans[msg.sender].isProvider){
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
        if(subscriptions[_planId][msg.sender].startTimeStamp == 0 ){
            revert NotSubscribed(msg.sender, _planId);
        }
        _;
    }


    /** Functions */

    /** External Functions*/

    function createPlan(uint64 _planId, uint256 _price, uint32 _duration) external planNotExists(_planId){
        if(_duration == 0){
            revert DurationCantBeZero();
        }

        Plans[_planId] = plan(_price, 0, _duration,true, msg.sender);
        ProviderPlans[msg.sender].planIds.push(_planId);
        ProviderPlans[msg.sender].isProvider = true;

        emit PlanCreated(_planId, _price, _duration, msg.sender,ProviderPlans[msg.sender].providerBalance,true,0);
        
    }

    function updatePlan(uint64 _planId, uint256 _price, uint32 _duration) external planExists(_planId) onlyProvider{
        if(_duration == 0){
            revert DurationCantBeZero();
        }

        Plans[_planId].price = _price;
        Plans[_planId].duration = _duration;

        emit PlanUpdated(_planId, _price, _duration, msg.sender, ProviderPlans[msg.sender].providerBalance,true,0);
    }

    function subscribe(uint64 _planId) external payable planExists(_planId){
        if(!Plans[_planId].isActive ){
            revert PlanNotActive();
        }
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
        ProviderPlans[Plans[_planId].provider].providerBalance += Plans[_planId].price;

        if (overpaidAmount > 0) {
            (bool success, ) = payable(msg.sender).call{value: overpaidAmount}("");
            require(success, RefundFailed());
            emit RefundIssued(_planId, msg.sender, overpaidAmount);
        }

        emit PlanSubscribed(msg.sender , _planId, subscriptions[_planId][msg.sender].totalAmountPaid, subscriptions[_planId][msg.sender].startTimeStamp, subscriptions[_planId][msg.sender].expiryTimeStamp);
    
    }

    function renew(uint64 _planId) external payable onlySubscribers(_planId) {

        if(!Plans[_planId].isActive ){
            revert PlanNotActive();
        }

        if(msg.value < Plans[_planId].price){
            revert InsufficientFunds(Plans[_planId].price, msg.value);
        }

        
        subscriptions[_planId][msg.sender].startTimeStamp = block.timestamp > subscriptions[_planId][msg.sender].expiryTimeStamp ? block.timestamp : subscriptions[_planId][msg.sender].startTimeStamp;
        subscriptions[_planId][msg.sender].expiryTimeStamp = block.timestamp > subscriptions[_planId][msg.sender].startTimeStamp ?  block.timestamp + Plans[_planId].duration : subscriptions[_planId][msg.sender].expiryTimeStamp + Plans[_planId].duration;
        subscriptions[_planId][msg.sender].totalAmountPaid  += Plans[_planId].price;
        ProviderPlans[Plans[_planId].provider].providerBalance += Plans[_planId].price;

        emit PlanRenewed(msg.sender , _planId, subscriptions[_planId][msg.sender].totalAmountPaid, subscriptions[_planId][msg.sender].startTimeStamp, subscriptions[_planId][msg.sender].expiryTimeStamp);
    }

    function withdrawFunds() external onlyProvider(){
        uint256 amount = ProviderPlans[msg.sender].providerBalance ;

        if(amount == 0){
            revert NothingToWithdraw();
        } 

        ProviderPlans[msg.sender].providerBalance = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        
        if(!success){
            ProviderPlans[msg.sender].providerBalance = amount;
            revert WithdrawFailed();
        }

        emit FundsWithdrawn(msg.sender, amount);
    }

    function disablePlan(uint64 _planId) external onlyProvider{
        Plans[_planId].isActive = false;
        Plans[_planId].deactivationTimeStamp = block.timestamp;
        emit PlanUpdated(_planId, Plans[_planId].price, Plans[_planId].duration, msg.sender, ProviderPlans[msg.sender].providerBalance,false,block.timestamp);

    }   

    function reActivatePlan(uint64 _planId) external onlyProvider planExists(_planId) {
        plan storage p = Plans[_planId];
        if (p.isActive) revert PlanAlreadyActive();

        p.isActive = true;
        p.deactivationTimeStamp = 0;

        emit PlanUpdated(_planId, p.price, p.duration, msg.sender, ProviderPlans[msg.sender].providerBalance, true, 0);
    }

    function cancelSubscription(uint64 _planId) external onlySubscribers(_planId) {
        uint256 refunded = _processRefund(_planId, msg.sender, block.timestamp);
        emit subscriptionCancelled(_planId, msg.sender, refunded);
    }

    function claimRefund(uint64 _planId) external planExists(_planId) {
        if (Plans[_planId].isActive) revert PlanAlreadyActive();
        uint256 refunded = _processRefund(_planId, msg.sender, Plans[_planId].deactivationTimeStamp);
        emit subscriptionCancelled(_planId, msg.sender, refunded);
    }

    /** Public Functions*/

    function isSubscriptionActive(uint64 planId, address user) public view returns(bool){
        if(subscriptions[planId][user].expiryTimeStamp > block.timestamp){
            return true;
        }else{
            return false;
        }
    }

    function isSubscriptionActive(uint64 planId) public view returns(bool){
        if(subscriptions[planId][msg.sender].expiryTimeStamp > block.timestamp){
            return true;
        }else{
            return false;
        }
    }

    

    

    
    /** Internal Functions*/

    function _processRefund(uint64 _planId, address user, uint256 endTime) internal returns (uint256) {
        subscription storage sub = subscriptions[_planId][user];
        if (sub.expiryTimeStamp <= endTime) revert NotSubscribed(user, _planId);

        uint256 unusedAmount = (sub.expiryTimeStamp - endTime) * Plans[_planId].price / Plans[_planId].duration;

        sub.expiryTimeStamp = 0; // prevent double refunds

        providerDetails storage provider = ProviderPlans[Plans[_planId].provider];
        if (provider.providerBalance >= unusedAmount) {
            provider.providerBalance -= unusedAmount;
        } else {
            unusedAmount = provider.providerBalance;
            provider.providerBalance = 0;
        }

        (bool success, ) = payable(user).call{value: unusedAmount}("");
        require(success, RefundFailed());

        return unusedAmount;
    }

    /** View functions */

    function getProviderPlans(address provider) external view returns (uint64[] memory) {
        return ProviderPlans[provider].planIds;
    }
    
}