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
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/dev/vrf/libraries/VRFV2PlusClient.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

error Raffle_NotEnoughEth();
error Raffle_TimeNotPassed();
error Raffle_TransferFailed();
error Raffle_RaffleNotOpen();
error Raffle_UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

contract Raffle is VRFConsumerBaseV2Plus {
    // Type declarations
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entraceFee;
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinatorContract;

    RaffleState private s_raffleState;
    address payable[] private s_players;
    address private s_recentWinner;
    uint256 private s_lastTimeStamp;

    event EnteredRaffle(address indexed player);
    event WinnerPicked(address winner);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 keyHash,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entraceFee = entranceFee;
        i_interval = interval;
        i_keyHash = keyHash;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;

        i_vrfCoordinatorContract = VRFCoordinatorV2Interface(vrfCoordinator);
    }

    function enterRaffle() external payable {
        // NOT VERY GAS EFFICIENT
        // require(msg.value >= i_entraceFee, "Not enough ETH sent");  //LEAST GAS EFFICIENT DUE TO STRINGS
        // require(msg.value >= i_entraceFee, NotEnoughEth());   //REVERTS WITH CUSTOM ERROR, MORE GAS EFFICIENT

        // MOST GAS EFFICIENT
        if (msg.value < i_entraceFee) {
            revert Raffle_NotEnoughEth();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle_RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    function checkUpkeep(bytes memory /* checkData */ )
        external
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool isOpen = (s_raffleState == RaffleState.OPEN);
        bool timePassed = (block.timestamp - s_lastTimeStamp > i_interval);
        bool hasPlayers = (s_players.length > 0);
        bool hasBalance = (address(this).balance > 0);

        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
        return (upkeepNeeded, "0x0");
    }
    // This function is called by the Chainlink Keeper network
    // It checks if the upkeep is needed and if so, it calls the pickWinner function

    // Get a random number
    // Use a random number to pick a player
    // Be automatically called
    function performUpkeep(bytes calldata /* performData */ ) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle_UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        // // Check if enough time has passed
        // if (block.timestamp - s_lastTimeStamp > i_interval) {
        //     revert Raffle_TimeNotPassed();
        // }

        s_raffleState = RaffleState.CALCULATING;

        // s_vrfCoordinator is a coordinator which requests random number from the Chainlink oracle.

        // VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
        //     keyHash: i_keyHash,
        //     subId: i_subscriptionId,
        //     requestConfirmations: REQUEST_CONFIRMATIONS,
        //     callbackGasLimit: i_callbackGasLimit,
        //     numWords: NUM_WORDS,
        //     extraArgs: VRFV2PlusClient._argsToBytes(
        //         // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
        //         VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
        //     )
        // });

        // uint256 requestId = s_vrfCoordinator.requestRandomWords(request);

        uint256 requestId = i_vrfCoordinatorContract.requestRandomWords(
            i_keyHash, i_subscriptionId, REQUEST_CONFIRMATIONS, i_callbackGasLimit, NUM_WORDS
        );
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;

        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit EnteredRaffle(recentWinner);
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle_TransferFailed();
        }
    }
}
