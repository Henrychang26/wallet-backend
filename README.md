# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
```

// Wallet

// modifier isSupportedToken(address token) {

// }

// you can deposit tokens or ETH into the Wallet
// you can withdraw tokens or ETH from the Wallet
// you can supply, borrow, repay, withdraw tokens from Aave V3
// you can swap tokens via Uniswap V3

// supply, borrow, repay, withdraw tokens on Aave V3

// scenario: you have WMATIC but you want to deposit USDC on Aave V3
// 1) deposit WMATIc into the Wallet
// 2) swap WMATIC to USDC on Uniswap V3 pool
// 3) deposit swapped USDC into Aave V3
// 4) receives aUSDC

// functions
// swap(tokenIn, tokenOut, fee, amountIn, amountOutMin)
// deposit(token, amount)
// withdraw(token, amount)

// supplyAaveV2(token, amount)
// borrowAaveV2()
// repayAaveV2()
// withdrawAaveV2()

// getAaveTokenAddress(token) => returns aToken and debtToken address

/\*

mapping(address => Balance) balances

struct Balance {
uint256 underlying => WMATIC //Balance
uint256 collateral => aWMATIC //Amount supplied -> aToken
uint256 debt => dWMATIC //Amount owed
}

address public immutable owner;

constructor(address \_owner) {
owner = \_owner;
}

\*\*/

/\*

LiquidityProvider: behaves as a liquidity provider on different dex protocols (V2, V3, Curve, etc)

\*\*/

/\*

Factory: deploys the Wallet contract

    function deploy(
        uint256[] memory moduleIds
    ) external returns (address client) {
        bytes20 targetBytes = bytes20(implementation);
        uint256 nonce = nonces[msg.sender];
        bytes32 salt = keccak256(abi.encodePacked(nonce, msg.sender));

        assembly {
            let ptr := mload(0x40)

            mstore(
                ptr,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(ptr, 0x14), targetBytes)
            mstore(
                add(ptr, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )

            client := create2(0, ptr, 0x37, salt)
        }

        if (client == address(0)) revert DeploymentFailed();

        if (!IClient(client).initialize(msg.sender))
            revert InitializationFailed();

        IModuleManager(client).update(Action.Add, getModules(moduleIds));
        // IModuleManager(client).update(Action.Add, _modules);

        clients[msg.sender][nonce] = client;

        unchecked {
            nonces[msg.sender] = nonce + 1;
        }

        emit ClientDeployed(msg.sender, client);
    }
         https://twitter.com/guil_lambert

         https://uniswapv3book.com/docs/milestone_1/first-swap/

         https://github.com/aave

\*\*/
