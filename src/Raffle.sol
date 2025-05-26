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


//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

error Raffle_NotEnoughEth();
error Raffle_TimeNotPassed();

contract Raffle {
    uint256 immutable i_entraceFee;
    address payable[] private s_players;
    uint256 private immutable i_interval;
    uint256 private immutable s_lastTimeStamp;

    event EnteredRaffle(address indexed player);

    constructor(uint256 entranceFee, uint256 interval) {
        i_entraceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
    }

    function enterRaffle() external payable{

        // NOT VERY GAS EFFICIENT
        // require(msg.value >= i_entraceFee, "Not enough ETH sent");  //LEAST GAS EFFICIENT DUE TO STRINGS
        // require(msg.value >= i_entraceFee, NotEnoughEth());   //REVERTS WITH CUSTOM ERROR, MORE GAS EFFICIENT

        // MOST GAS EFFICIENT
        if (msg.value < i_entraceFee) {
            revert Raffle_NotEnoughEth();
        }

        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    // Get a random number 
    // Use a random number to pick a player
    // Be automatically called 
    function pickWinner() external {

        // Check if enough time has passed
        if(block.timestamp - s_lastTimeStamp > i_interval){
            revert Raffle_TimeNotPassed();
        }


    }
}