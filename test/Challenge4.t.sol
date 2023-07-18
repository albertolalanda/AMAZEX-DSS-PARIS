// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {VaultFactory} from "../src/4_RescuePosi/myVaultFactory.sol";
import {VaultWalletTemplate} from "../src/4_RescuePosi/myVaultWalletTemplate.sol";
import {PosiCoin} from "../src/4_RescuePosi/PosiCoin.sol";

/*////////////////////////////////////////////////////////////
//          DEFINE ANY NECESSARY CONTRACTS HERE             //
//    If you need a contract for your hack, define it below //
////////////////////////////////////////////////////////////*/



/*////////////////////////////////////////////////////////////
//                     TEST CONTRACT                        //
////////////////////////////////////////////////////////////*/
contract Challenge4Test is Test {
    VaultFactory public FACTORY;
    PosiCoin public POSI;
    address public unclaimedAddress = 0x70E194050d9c9c949b3061CC7cF89dF9c6782b7F;
    address public whitehat = makeAddr("whitehat");
    address public devs = makeAddr("devs");

    function setUp() public {
        vm.label(unclaimedAddress, "Unclaimed Address");

        // Instantiate the Factory
        FACTORY = new VaultFactory();

        // Instantiate the POSICoin
        POSI = new PosiCoin();

        // OOPS transferred to the wrong address!
        POSI.transfer(unclaimedAddress, 1000 ether);
    }


    function testWhitehatRescue() public {
        vm.deal(whitehat, 10 ether);
        vm.startPrank(whitehat, whitehat);
        /*////////////////////////////////////////////////////
        //               Add your hack below!               //
        //                                                  //
        // terminal command to run the specific test:       //
        // forge test --match-contract Challenge4Test -vvvv //
        ////////////////////////////////////////////////////*/

        // @audit Factory address is the same as the 'EOA' that triggered the trasaction.
        // Create2 address is calculated by the msg.sender address + salt + creation code
        // We will use FACTORY to call the deploy() wich will create2 the new wallet contract.
        assertEq(address(FACTORY), 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f); 
        // guess that the salt was 11, the month of the emplyees birthday 
        FACTORY.callWallet(
            address(FACTORY),
            abi.encodeWithSignature(
                "deploy(bytes,uint256)",
                type(VaultWalletTemplate).creationCode,
                uint256(11) 
            )
        );
        VaultWalletTemplate vaultWallet = VaultWalletTemplate(unclaimedAddress);
        vaultWallet.initialize(whitehat);

        // the ERC20 that we need were given to the address we just created, we just need to transfer them to the devs
        vaultWallet.withdrawERC20(address(POSI), 1000 ether, devs);
        
        console.log("FACTORY address: %s", address(FACTORY));

        //==================================================//
        vm.stopPrank();

        assertEq(POSI.balanceOf(devs), 1000 ether, "devs' POSI balance should be 1000 POSI");
    }
}
