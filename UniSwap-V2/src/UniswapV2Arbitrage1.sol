// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import {IERC20} from "@uniswap/v2-core/contracts/interfaces/IERC20.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {Constants} from "./Constants.sol";
import {ERC20} from "./ERC20.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract UniswapV2Arbitrage1 {
    error InsufficientProfit();

    struct SwapParams {
        address router0;
        address router1;
        address token0; // tokens must be stored in sorted order..
        address token1;
        uint256 amountIn;
        uint256 amountOutMin;
        uint256 minProfit;
        bool isToken0;
    }

    SwapParams public swapParams;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function _swap(SwapParams memory params) internal returns (uint256) {
        // swapping from token0 -> token1 and then from token1 -> token0

        address tokenA;
        address tokenB;

        if (params.isToken0) {
            tokenA = params.token0;
            tokenB = params.token1;
        } else {
            tokenA = params.token1;
            tokenB = params.token0;
        }

        IERC20(tokenA).approve(params.router0, params.amountIn);

        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;

        uint256 amountIn = params.amountIn;
        uint256[] memory amounts = IUniswapV2Router02(params.router0)
            .swapExactTokensForTokens({
                amountIn: amountIn,
                amountOutMin: params.amountOutMin,
                path: path,
                to: address(this),
                deadline: block.timestamp + 1000
            });

        // approving by this contract

        IERC20(tokenB).approve(params.router1, amounts[1]);

        path[0] = tokenB;
        path[1] = tokenA;

        amounts = IUniswapV2Router02(params.router1)
            .swapExactTokensForTokens({
                amountIn: amounts[1], amountOutMin: 1, path: path, to: address(this), deadline: block.timestamp + 1000
            });

        return amounts[1];
    }

    // Exercise 1
    // - Execute an arbitrage between router0 and router1
    // - Pull token0 from msg.sender
    // - Send amountIn + profit back to msg.sender
    function swap(SwapParams calldata params) external {
        // implement arbitrage logic here

        IERC20(params.token0).transferFrom(msg.sender, address(this), params.amountIn);
        uint256 amountOut = _swap(params);
        if (amountOut - params.amountIn < params.minProfit) {
            revert InsufficientProfit();
        }
        IERC20(params.token0).transfer(msg.sender, amountOut);
    }

    // Exercise 2
    // - Execute an arbitrage between router0 and router1 using flash swap
    // - Borrow token0 with flash swap from pair
    // - Send profit back to msg.sender
    function flashSwap(address pair, bool isToken0, SwapParams memory params) external {
        // implement flash swap logic here

        bytes memory data = abi.encode(msg.sender, pair, params);

        require(pair != address(0), "Invalid pair address");
        IUniswapV2Pair(pair)
            .swap({
                amount0Out: isToken0 ? params.amountIn : 0,
                amount1Out: isToken0 ? 0 : params.amountIn,
                to: address(this),
                data: data
            });
    }

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        // implement uniswapV2Call logic here
        (address caller, address pair, SwapParams memory params) = abi.decode(data, (address, address, SwapParams));
        require(sender == address(this), "not this contract");
        require(msg.sender == pair, "not called by the pair contract");

        uint256 amountOut = _swap(params);

        uint256 fee = ((params.amountIn * 3) / 997) + 1; // extra one for rounding errors.
        uint256 amountTorepay = params.amountIn + fee;

        uint256 profit = amountOut - amountTorepay;

        require(profit >= params.minProfit, "not sufficent profit");

        address token = params.token0;

        IERC20(token).transfer(pair, amountTorepay);
        IERC20(token).transfer(caller, profit);
    }
}
