// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import {IERC20} from "@uniswap/v2-core/contracts/interfaces/IERC20.sol";
import {
    IUniswapV2Router02
} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {Constants} from "../src/Constants.sol";
import {ERC20} from "../src/ERC20.sol";
import {
    IUniswapV2Pair
} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {
    IUniswapV2Factory
} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

import {UniswapV2Flashloan} from "../src/UniswapV2Flashloan.sol";


contract UniswapV2FlashloanTest is Test {
     IWETH private weth;
    IERC20 private dai;
    IERC20 private mkr;
    IUniswapV2Router02 private router;

    function setUp() public {
        weth = IWETH(Constants.WETH);
        dai = IERC20(Constants.DAI);
        mkr = IERC20(Constants.MKR);
        router = IUniswapV2Router02(Constants.UNISWAP_V2_ROUTER_02);
    }

    function testFlashloan() public {
        UniswapV2Flashloan flashloan = new UniswapV2Flashloan();

        address user = address(0xABCD);
        vm.deal(user, 1000* 10**18);
        deal(address(dai), user, 10000 * 10**18); // Give user 10,000 DAI


        address pair = IUniswapV2Factory(Constants.UNISWAP_V2_FACTORY).getPair(
            Constants.DAI,
            Constants.WETH
        );
        console.log("Uniswap V2 DAI-WETH Pair Address:", pair);
        (uint reserve0, uint reserve1, ) = IUniswapV2Pair(pair).getReserves();
        if(address(dai) < address(weth)){
            console.log("DAI Reserve:", reserve0);
            console.log("WETH Reserve:", reserve1);
        } else {
            console.log("DAI Reserve:", reserve1);
            console.log("WETH Reserve:", reserve0);
        }
         
         vm.startPrank(user);
        // token approving for covering the flash seap fee 
         weth.deposit{value: 1000* 10**18}();
         dai.approve(address(flashloan), 10000 * 10**18);
         weth.approve(address(flashloan), 1000* 10**18);
        
        // Perform a flash swap to borrow 1000 DAI
        uint amountToBorrowDai = 1000 * 10**18; // 1000 DAI with 18 decimals
        uint amountToBorrowWeth = 1000 * 10**18; // 1000 WETH with 18 decimals
        (address factory, address routerAddr, address tokenA, address tokenB) = flashloan.flashSwap(
            Constants.UNISWAP_V2_FACTORY,
            Constants.UNISWAP_V2_ROUTER_02,
            Constants.DAI,
            Constants.WETH,
            amountToBorrowDai,
            amountToBorrowWeth
        );

        vm.stopPrank();

        console.log("Flash swap executed from factory:", factory);
        console.log("Using router:", routerAddr);
        console.log("Borrowed token A (DAI):", tokenA);
        console.log("Borrowed token B (WETH):", tokenB);
        console.log("Amount borrowed DAI:", amountToBorrowDai);
        console.log("Amount borrowed WETH:", amountToBorrowWeth);
    }
}