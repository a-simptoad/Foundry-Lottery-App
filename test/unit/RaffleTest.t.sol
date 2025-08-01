// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    event EnteredRaffle(address indexed player);
    event WinnerPicked(address winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE); // gives the player address funds
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    // Entering the Raffle

    function testRaffleRevertsWhenYouDontPayEnough() public {
        //Arrange 
        vm.prank(PLAYER); // this line makes the transaction after it to be performed by the player.

        //Act / Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEth.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        //Arrange
        vm.prank(PLAYER);

        //Act
        raffle.enterRaffle{value: entranceFee}();

        //assert
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);   
    }

    // Testing Event Emits

    function testEnteringRaffleEmitsEvents() public {
        // Arrange
        vm.prank(PLAYER);

        //Act
        vm.expectEmit(true, false, false, false, address(raffle)); // first three bools are for indexed parameters and last is for non indexed parameters. true defines that the topic is to be emitted
        emit EnteredRaffle(PLAYER);

        //Assert
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); // Changes the time in the simulated environment
        vm.roll(block.number + 1);// Changes the blocknumber in the simulation
        raffle.performUpkeep("");
        // performUpkeep reverts as we have not setup any subscription which is necessary for the mockVRFCoordinator
        // Hence we need a subId and fund it in the interactions.s.sol

        //Act
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

    }

    //CheckUPkeeep
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange 
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");

        //assert
        assert(!upKeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
        //Arrange 
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep(""); // Raffle not open now

        //Act 
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");

        //Assert 
        assert(!upKeepNeeded); 
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasPassed() public {
        // Arrange 
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval /2 );

        //Act 
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueIfAllParametersAreGood() public {
        // Arrange 
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        
        //Act 
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //Assert 
        assert(upkeepNeeded);
    }

    // Perform UPkeep tests
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp+interval+1);
        vm.roll(block.number + 1);

        // Act / Assert
        raffle.performUpkeep("");

        //Assert 
        // assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        //Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayers = 1;

        //Act/ Assert 
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, rState));
        raffle.performUpkeep("");

        // This error which is reverted contains the data passed as parameters in the contract while defining
    } 

    modifier raffleEntered {
        // Arrange 
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp+interval+1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered{
        //Act 
        vm.recordLogs();  
        raffle.performUpkeep(""); // This tells the vm to keep record of all the logs created when this performUpkeep() functioin is called
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert 
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    // Fuzz Testing

    // FullFillRandomWords ////////////////////////

    // Stateless Fuzz Test
    function testFullFillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomId) public {
        // Arrange / Act / Assert 
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomId, address(raffle));
    }

    function testFulfillRandomWordsPickWinnerResetsAndSendsMoney() public raffleEntered {
        // Arrange
        uint256 additionalEntrants = 3; // total 4 -> one from modifier
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for(uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++){
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value:entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        //Act 
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        //Assert 
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState rafflestate = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(winnerBalance == winnerStartingBalance + prize);
        assert(recentWinner == expectedWinner);
        assert(uint256(rafflestate) == 0);
        assert(endingTimeStamp > startingTimeStamp);
    }
}