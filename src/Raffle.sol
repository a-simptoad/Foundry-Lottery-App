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

error NotEnoughEth();

contract Raffle {
    uint256 immutable i_entraceFee;
    address payable[] private s_players;

    event EnteredRaffle(address indexed player);

    constructor(uint256 entranceFee) {
        i_entraceFee = entranceFee;
    }

    function enterRaffle() public payable{

        // NOT VERY GAS EFFICIENT
        // require(msg.value >= i_entraceFee, "Not enough ETH sent");  //LEAST GAS EFFICIENT DUE TO STRINGS
        // require(msg.value >= i_entraceFee, NotEnoughEth());   //REVERTS WITH CUSTOM ERROR, MORE GAS EFFICIENT

        // MOST GAS EFFICIENT
        if (msg.value < i_entraceFee) {
            revert NotEnoughEth();
        }

        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    function pickWinner() public{

    }
}