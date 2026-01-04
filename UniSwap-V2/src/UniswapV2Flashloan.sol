import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import {IERC20} from "@uniswap/v2-core/contracts/interfaces/IERC20.sol";
import {
    IUniswapV2Router02
} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {Constants} from "./Constants.sol";
import {ERC20} from "./ERC20.sol";
import {
    IUniswapV2Pair
} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {
    IUniswapV2Factory
} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract UniswapV2Flashloan {
    address private constant UNISWAP_V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address private constant UNISWAP_V2_ROUTER02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    IUniswapV2Factory public factory;
    IUniswapV2Router02  public router;
    IUniswapV2Pair  public pair;
    IERC20  public token0;
    IERC20  public token1;
    IWETH  public weth;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function flashSwap(address factoryA,address routerA,address tokenA,address tokenB, uint amountA , uint amountB) public returns(address ,address,address,address){
        require(factoryA != address(0) && routerA != address(0), "Invalid address");
        factory = IUniswapV2Factory(factoryA);
        router = IUniswapV2Router02(routerA);
        token0 = IERC20(tokenA);
        token1 = IERC20(tokenB);
        weth = IWETH(WETH);
       
       // swapping logic 

       pair = IUniswapV2Pair(factory.getPair(tokenA, tokenB));
       require(address(pair) != address(0), "Pool does not exist");

      bytes memory data = abi.encode(amountA, amountB, msg.sender);
      pair.swap(amountA, amountB, address(this), data);
      return (address(factory), address(router), address(tokenA), address(tokenB));
    }

   function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external {
        require(msg.sender == address(pair), "Unauthorized");
        require(sender == address(this), "Not from contract");

        (uint amountA, uint amountB, address initiator) = abi.decode(data, (uint, uint, address));

        // Implement your custom logic here
        // For example, arbitrage, liquidation, etc.

        // Calculate the amount to repay
        uint feeA = ((amount0 * 3) / 997) + 1;          // extra one for rounding errors.
        uint feeB = ((amount1 * 3) / 997) + 1;

        token0.transferFrom(initiator, address(this), feeA);
        token1.transferFrom(initiator, address(this), feeB);

        if (amount0 > 0) {
            token0.transfer(address(pair), amount0 + feeA);
        }
        if (amount1 > 0) {
            token1.transfer(address(pair), amount1 + feeB);
        }
   }
    



}
        

