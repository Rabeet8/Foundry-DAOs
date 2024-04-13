//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {MyGovernor} from "../src/MyGovernor.sol";
import {Box} from "../src/Box.sol";
import {GovToken} from "../src/GovToken.sol";
import {Timelock} from "../src/Timelock.sol";
import {Test,console} from "forge-std/Test.sol";

contract MyGovernorTest is Test{

    MyGovernor governor;
    Box box;
    TimeLock timelock;
    GovToken govtToken;

    uint256 public constant MIN_DELAY = 3600;
    uint256 public constant VOTING_DELAY = 1; 
    uint256 public constant VOTING_PERIOD = 50400;


    address [] proposers;
    address [] executors;
    uint256 [] values;
    bytes [] calldatas;
    address [] targets;


    address public USER = makeAddr("user");
    function setUp() public {

        govToken = new GovToken();
        govToken.mint(USER,INITIAL_SUPPLY);
        vm.startPrank(USER);
        govToken.delegate(USER);
        timelock = new TimeLock(MIN_DELAY,proposers,executors);
        governor = new MyGovernor(govToken,timelock);

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.TIMELOCK_ADMIN_ROLE();

        timelock.grantRole(proposerRole,address(governor));
        timelock.grantRole(executorRole,address(0));
        timelock.grantRole(adminRole,address(USER));

        vm.stopPrank();
        box = new Box();

        box.transferOwnership(address(timelock));
    }

    function testCanUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        box.store(1);
    }

    function testGovernanceUpdatesBox() public {
        uint256 valueToStore = 999;

        string memory description = "store in 1 box";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);
        values.push(0);
        calldatas.push(encodedFunctionCall);
        targets.push(address(box));

        //propose to the dao
        uint256 proposalId = governor.propose(targets,values,calldatas,description);

        //view the state
        console.log("Proposal State",uint256(governor.state(proposalId)));

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.NUMBER + VOTING_DELAY + 1);

        console.log("Proposal State: ," uint256(governor.state(proposalId)));

        //2.Vote

        string memory reason = "abcdee"; 

        uint8 voteWay = 1; //voting yes

        vm.prank(USER);

        governor.castVoteWithReason(proposalId,voteWay,reason);

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.NUMBER + VOTING_DELAY + 1);

        // Queue the TX

        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets,values,calldatas,descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.NUMBER + MIN_DELAY + 1);
        //Execute

        governor.execute(targets,values,calldatas,descriptionHash);

        assert(box.getNumber() == valueToStore);
        console.log("BOX VALUE",box.getNumber);
    }
}