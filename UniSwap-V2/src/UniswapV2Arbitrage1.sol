// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import {IERC20} from "@uniswap/v2-core/contracts/interfaces/IERC20.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {Constants} from "./Constants.sol";
import {ERC20} from "./ERC20.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract Arbitrage1 {
    struct SwapParams {
        address router0;
        address router1;
        address token0;
        address token1;
        uint256 amountIn;
        uint256 amountOutMin;
        uint256 minProfit;
    }

    SwapParams public swapParams;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function _swap(SwapParams memory params) internal returns (uint256) {
        // swapping from token0 -> token1 and then from token1 -> token0
        address[] memory path = new address[2];
        path[0] = params.token0;
        path[1] = params.token1;

        uint256 amountIn = params.amountIn;
        uint256[] memory amounts = IUniswapV2Router02(params.router0)
            .swapExactTokensForTokens({
                amountIn: amountIn,
                amountOutMin: amountOutMin,
                path: path,
                to: address(this),
                deadline: block.timestamp + 1000
            });

        // approving by this contract

        params.token1.approve(params.router1, amounts[1]);

        path[0] = token1;
        path[1] = token0;

        amounts = IUniswapV2Router02(params.router1)
            .swapExactTokensForTokens({
                amountIn: amounts[1],
                amountOutMin: params.amountIn,
                path: path,
                to: address(this),
                deadline: block.timestamp + 1000
            });

        return amounts[1];
    }

    function swap() external {
        // implement arbitrage logic here
    }

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
        (address caller, address pair, SwapParams params) = abi.decode(data, (address, address, SwapParams));
        require(sender == address(this), "not this contract");
        require(msg.sender == pair, "not called by the pair contract");

        uint256 amountOut = _swap(params);

        uint256 fee = ((params.amountIn * 3) / 997) + 1; // extra one for rounding errors.
        unit256 amountTorepay = params.amountIn + fee;

        uint256 profit = amountOut - amountTorepay;

        require(profit >= params.minProfit, "not sufficent profit");

        IERC20(token0).transfer(pair, amountTorepay);
        IERC20(token0).transfer(caller, profit);
    }
}
