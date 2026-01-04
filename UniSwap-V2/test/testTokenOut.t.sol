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
contract uniSwapv2 is Test {
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
    function test_getAmountOut() public view {
        address[] memory path = new address[](3);
        path[0] = address(weth);
        path[1] = address(dai);
        path[2] = address(mkr);
        uint amountIn = 1e18; // 1 WETH
        uint[] memory amountsOut = router.getAmountsOut(amountIn, path);
        console.log("Amount of weth inned", amountsOut[0]);
        console.log("Amount of dai", amountsOut[1]);
        console.log("Amount of mkr", amountsOut[2]);

        //       Amount of weth inned 1.000000000000000000
        // Amount of dai 3089.528293800335233768
        // Amount of mkr 0.045746694922597088
    }

    function test_getAmountIn() public view {
        address[] memory path = new address[](3);
        path[0] = address(weth);
        path[1] = address(dai);
        path[2] = address(mkr);
        uint256 amountOut = 1e16; // 1e18 will cause an error: `[Revert] ds-math-sub-underflow`
        uint[] memory amountsIn = router.getAmountsIn(amountOut, path);
        console.log("Amount of weth needed", amountsIn[0]);
        console.log("Amount of dai needed", amountsIn[1]);
        console.log("Amount of mkr out", amountsIn[2]);

        //       Amount of weth needed 6054548944057446
        // Amount of dai needed 18714783758475040778
        // Amount of mkr out 0.0010000000000000000
    }

    function test_swapExactTokensForTokens() public {
        address user = address(1);
        vm.deal(user, 10e18); // give user 10 WETH
        address[] memory path = new address[](3);
        path[0] = address(weth);
        path[1] = address(dai);
        path[2] = address(mkr);
        uint amountIn = 1e18; // 1 WETH
        uint amountOutMin = 1e15; // 0.001 MKR
        vm.startPrank(user);
        weth.deposit{value: amountIn}();
        weth.approve(address(router), amountIn);
        uint[] memory amounts = router.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: amountOutMin,
            path: path,
            to: user,
            deadline: block.timestamp + 1000
        });
        vm.stopPrank();
        console.log("Amount of weth spent", amounts[0]);
        console.log("Amount of dai bought", amounts[1]);
        console.log("Amount of mkr bought", amounts[2]);

        assertGt(amounts[2], amountOutMin, "Did not receive enough MKR");
        //       Amount of weth spent 1000000000000000000
        // Amount of dai bought 3089528293800335233768
        // Amount of mkr bought 46555118693399564
    }
    function test_swapTokensForExactTokens() public {
        address user = address(1);
        vm.deal(user, 10e18); // give user 10 WETH
        address[] memory path = new address[](3);
        path[0] = address(weth);
        path[1] = address(dai);
        path[2] = address(mkr);
        uint amountOut = 1e16; // 0.01 MKR
        uint amountInMax = 1e18; // 1 WETH

        vm.startPrank(user);
        weth.deposit{value: amountInMax}();
        weth.approve(address(router), amountInMax);
        uint[] memory amounts = router.swapTokensForExactTokens({
            amountOut: amountOut,
            amountInMax: amountInMax,
            path: path,
            to: user,
            deadline: block.timestamp + 1000
        });
        vm.stopPrank();
        console.log("Amount of weth spent", amounts[0]);
        console.log("Amount of dai bought", amounts[1]);
        console.log("Amount of mkr bought", amounts[2]);
        assertEq(amounts[2], amountOut, "Did not receive exact MKR");
        assertGt(amountInMax, amounts[0], " spending is greater than max");
        //       Amount of weth spent 5823788219822373
        // Amount of dai bought 18001497796751046760
        // Amount of mkr bought 10000000000000000
    }
    function test_createPair() public {
        address factory = Constants.UNISWAP_V2_FACTORY;
        ERC20 tokenA = new ERC20("TokenA", "TKA", 18);
        address pair = IUniswapV2Factory(factory).createPair(
            address(tokenA),
            address(weth)
        );
        console.log("New pair address:", pair);
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();
        console.log("Token0 address:", token0);
        console.log("Token1 address:", token1);
        if (address(tokenA) < address(weth)) {
            assertEq(token0, address(tokenA), "Token0 should be TokenA");
            assertEq(token1, address(weth), "Token1 should be WETH");
        } else {
            assertEq(token0, address(weth), "Token0 should be WETH");
            assertEq(token1, address(tokenA), "Token1 should be TokenA");
        }

        // New pair address: 0x35318373409608AFC0f2cdab5189B3cB28615008
        // Token0 address: 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
        // Token1 address: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
        //
    }

    function test_addLiquidity() public {
        address user = address(1);
        vm.deal(user, 10e18); // give user 10 WETH
        deal(address(dai), user, 20000e18); // give user 20000 DAI
        vm.startPrank(user);
        weth.deposit{value: 5e18}(); // deposit 5 WETH
        weth.approve(address(router), 5e18);
        dai.approve(address(router), 10000e18); // approve 10000 DAI
        (uint amountA, uint amountB, uint liquidity) = router.addLiquidity({
            tokenA: address(weth),
            tokenB: address(dai),
            amountADesired: 5e17,
            amountBDesired: 10000e18,
            amountAMin: 1,
            amountBMin: 1,
            to: user,
            deadline: block.timestamp + 1000
        });
        vm.stopPrank();

        address pair = IUniswapV2Factory(Constants.UNISWAP_V2_FACTORY).getPair(
            address(weth),
            address(dai)
        );

        console.log("Amount of WETH added:", amountA);
        console.log("Amount of DAI added:", amountB);
        console.log("Liquidity tokens received:", liquidity);
        assertEq(
            liquidity,
            IUniswapV2Pair(pair).balanceOf(user),
            "Liquidity tokens not received correctly"
        );

        //       Amount of WETH added: 500000000000000000  -> 5e17
        // Amount of DAI added: 1574.251519945248793173     -> 1574.251519945248793173  dai
        // Liquidity tokens received: 12.985837463326597943

        (uint reserve0, uint reserve1, ) = IUniswapV2Pair(pair).getReserves();
        if (address(weth) < address(dai)) {
            console.log("Reserve WETH:", reserve0);
            console.log("Reserve DAI:", reserve1);
        } else {
            console.log("Reserve WETH:", reserve1);
            console.log("Reserve DAI:", reserve0);
        }

        //      Reserve WETH: 2027.063613136462470627
        // Reserve DAI: 6372752.239419121772456169
        //  ratio = 6372752.239419121772456169 / 2027.063613136462470627 = ~3145.67dai/weth
    }

    // test to distort the ratio during adding liquidity.

    function test_addLiquidityWithDistortion() public {
        address user = address(1);
        vm.deal(user, 1000e18); // give user 1000 WETH
        deal(address(dai), user, 20000e18); // give user 20000 DAI
        vm.startPrank(user);
        weth.deposit{value: 5e18}(); // deposit 5 WETH
        weth.approve(address(router), 5e18);
        dai.approve(address(router), 10000e18); // approve 10000 DAI
        vm.stopPrank();

        // get reserves before adding liquidity
        address pair = IUniswapV2Factory(Constants.UNISWAP_V2_FACTORY).getPair(
            address(weth),
            address(dai)
        );
        (uint reserve0Before, uint reserve1Before, ) = IUniswapV2Pair(pair)
            .getReserves();

        uint reserveA;
        uint reserveB;

        if (address(weth) < address(dai)) {
            reserveA = reserve0Before;
            reserveB = reserve1Before;
        } else {
            reserveA = reserve1Before;
            reserveB = reserve0Before;
        }

        console.log(" total weth before adding anything", reserveA);
        console.log(" total dai before adding anything", reserveB);
        console.log("---- ratio before distortion ----", reserveB / reserveA);

        // add liquidity without distortion
        {
            vm.startPrank(user);
            (uint amountA, uint amountB, uint liquidity) = router.addLiquidity({
                tokenA: address(weth),
                tokenB: address(dai),
                amountADesired: 5e17,
                amountBDesired: 10000e18,
                amountAMin: 1,
                amountBMin: 1,
                to: user,
                deadline: block.timestamp + 1000
            });
            vm.stopPrank();

            console.log("Amount of WETH added:", amountA);
            console.log("Amount of DAI added:", amountB);
            console.log("Liquidity tokens received:", liquidity);
        }

        {
            (uint reserve0After, uint reserve1After, ) = IUniswapV2Pair(pair)
                .getReserves();
            uint reserveAAfter;
            uint reserveBAfter;

            if (address(weth) < address(dai)) {
                reserveAAfter = reserve0After;
                reserveBAfter = reserve1After;
            } else {
                reserveAAfter = reserve1After;
                reserveBAfter = reserve0After;
            }

            console.log(" total weth after adding liquidity", reserveAAfter);
            console.log(" total dai after adding liquidity", reserveBAfter);
            console.log(
                "---- ratio  without distortion and adding liquidity ----",
                reserveBAfter / reserveAAfter
            );
        }

        //  total weth before adding anything 2028.937812072234334060
        //    total dai before adding anything 6363747.316154778515916521
        //   ---- ratio before distortion ---- 3136
        //   Amount of WETH added: 0.500000000000000000
        //   Amount of DAI added: 1568.246024666283882496
        //   Liquidity tokens received: 12.961013437057530733
        //    total weth after adding liquidity 2029.437812072234334060
        //    total dai after adding liquidity 6365315.562179444799799017
        //   ---- ratio  without distortion and adding liquidity ---- 3136
        //   Amount of WETH added after distortion: 0.500000000000000000
        //   Amount of DAI added after distortion: 1568.246024666283882496
        //   Liquidity tokens received : 12.961013437057530733
        //    total weth after distortion and adding liquidity 2129.937812072234334060
        //    total dai after distortion and adding liquidity 6366883.808204111083681513
        //   ---- ratio  with distortion and adding liquidity ---- 2989
        // distoration in the ratio .

        vm.startPrank(user);
        weth.deposit{value: 106e18}();
        weth.approve(address(router), 5e18);
        dai.approve(address(router), 10000e18); // approve 10000 DAI

        // direct transfer to pair contract to distort the ratio
        weth.transfer(pair, 100e18); // distorting the ratio by transferring 100 WETH directly to pair contract

        (uint amountA, uint amountB, uint liquidity2) = router.addLiquidity({
            tokenA: address(weth),
            tokenB: address(dai),
            amountADesired: 5e17,
            amountBDesired: 10000e18,
            amountAMin: 1,
            amountBMin: 1,
            to: user,
            deadline: block.timestamp + 1000
        });
        vm.stopPrank();

        console.log("Amount of WETH added after distortion:", amountA);
        console.log("Amount of DAI added after distortion:", amountB);
        console.log("Liquidity tokens received :", liquidity2);

        (uint reserve0Final, uint reserve1Final, ) = IUniswapV2Pair(pair)
            .getReserves();
        uint reserveAFinal;
        uint reserveBFinal;

        if (address(weth) < address(dai)) {
            reserveAFinal = reserve0Final;
            reserveBFinal = reserve1Final;
        } else {
            reserveAFinal = reserve1Final;
            reserveBFinal = reserve0Final;
        }

        console.log(
            " total weth after distortion and adding liquidity",
            reserveAFinal
        );
        console.log(
            " total dai after distortion and adding liquidity",
            reserveBFinal
        );
        console.log(
            "---- ratio  with distortion and adding liquidity ----",
            reserveBFinal / reserveAFinal
        );
    }

    function test_removeLiquidity() public {
        address user = address(1);
        vm.deal(user, 10e18); // give user 10 WETH
        deal(address(dai), user, 20000e18); // give user 20000 DAI
        vm.startPrank(user);
        weth.deposit{value: 5e18}(); // deposit 5 WETH
        weth.approve(address(router), 5e18);
        dai.approve(address(router), 10000e18); // approve 10000 DAI
        (uint amount0, uint amount1, uint liquidity) = router.addLiquidity({
            tokenA: address(weth),
            tokenB: address(dai),
            amountADesired: 5e17,
            amountBDesired: 10000e18,
            amountAMin: 1,
            amountBMin: 1,
            to: user,
            deadline: block.timestamp + 1000
        });

        IUniswapV2Pair pair = IUniswapV2Pair(
            IUniswapV2Factory(Constants.UNISWAP_V2_FACTORY).getPair(
                address(weth),
                address(dai)
            )
        );

        console.log(" weth token added ", amount0);
        console.log(" dai token added ", amount1);
        console.log("Liquidity tokens of users :", pair.balanceOf(user));

        pair.approve(address(router), liquidity);
        (uint amountA, uint amountB) = router.removeLiquidity({
            tokenA: address(weth),
            tokenB: address(dai),
            liquidity: liquidity,
            amountAMin: 1,
            amountBMin: 1,
            to: user,
            deadline: block.timestamp + 1000
        });
        vm.stopPrank();

        console.log("Amount of WETH removed:", amountA);
        console.log("Amount of DAI removed:", amountB);

        console.log(
            "Liquidity tokens of users after removal:",
            pair.balanceOf(user)
        );
    }
}
