// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {V1Token} from "../src/V1Token.sol";
import {V1Exchange} from "../src/V1Exchange.sol";

import "forge-std/console.sol";

contract V1DefiTest is Test {
    V1Exchange public exchange;
    V1Token public token;

    address howy = makeAddr("howy");

    function setUp() public {
        vm.deal(howy, 10 ether);

        // Deploy token first
        token = new V1Token("NYI US Dollar", "NUSD");

        // Then deploy exchange with token address
        exchange = new V1Exchange(address(token));
    }

    function test_AddLiquidity() public {
        vm.startPrank(howy);

        uint256 tokenAmount = 5000;
        token.mint(howy, tokenAmount);
        // Approve exchange
        token.approve(address(exchange), tokenAmount);

        // Add liquidity
        exchange.addLiquidty{value: 1 ether}(tokenAmount);

        vm.stopPrank();

        // Check reserve
        assertEq(exchange.getReserve(), tokenAmount);
    }

    function test_AddLiquidity_CheckBalances() public {
        uint256 tokenAmount = 5000;

        // Give Howy some tokens first (important)
        token.mint(howy, tokenAmount);

        uint256 ethBefore = howy.balance;
        uint256 tokenBefore = token.balanceOf(howy);

        vm.startPrank(howy);

        token.approve(address(exchange), tokenAmount);

        exchange.addLiquidty{value: 1 ether}(tokenAmount);

        vm.stopPrank();

        uint256 ethAfter = howy.balance;
        uint256 tokenAfter = token.balanceOf(howy);

        // ✅ Check ETH reduced by 1 ether
        assertEq(ethBefore - ethAfter, 1 ether);

        // ✅ Check tokens reduced
        assertEq(tokenBefore - tokenAfter, tokenAmount);
    }

    function test_Swap_Eth_To_Token() public {
        address exchanger = makeAddr("exchanger");
        address nyi = makeAddr("nyi");

        address wpa = makeAddr("wpa");
        vm.deal(exchanger, 100 ether);
        vm.deal(nyi, 3 ether);
        vm.deal(wpa, 10 ether);

        uint256 tokenAmount = 5000 ether;

        vm.startPrank(exchanger);
        token.mint(exchanger, tokenAmount);
        token.approve(address(exchange), tokenAmount);
        exchange.addLiquidty{value: 10 ether}(tokenAmount);
        vm.stopPrank();

        vm.startPrank(nyi);
        exchange.swapEthToToken{value: 1 ether}(10 ether);
        console.log("Nyi ETH balance : ", nyi.balance / 1 ether);
        console.log("Nyi Token balance : ", token.balanceOf(nyi) / 1 ether);
        vm.stopPrank();

        vm.startPrank(wpa);
        exchange.swapEthToToken{value: 1 ether}(10 ether);
        console.log("WPA ETH balance : ", wpa.balance / 1 ether);
        console.log("WPA Token balance : ", token.balanceOf(wpa) / 1 ether);
        vm.stopPrank();

        console.log("Exchanger ETH balance : ", address(exchange).balance / 1 ether);
        console.log("Exchanger Token balance : ", token.balanceOf(address(exchange)) / 1 ether);
    }
}
