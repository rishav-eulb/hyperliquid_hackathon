# EIP-7540 Asynchronous Vault Implementation

This is a complete implementation of EIP-7540: Asynchronous ERC-4626 Tokenized Vaults.

## Overview

EIP-7540 extends ERC-4626 by adding support for asynchronous deposit and redemption flows. This is useful for:

- Real-world asset protocols
- Undercollateralized lending protocols
- Cross-chain lending protocols
- Liquid staking tokens
- Insurance safety modules
- Any protocol with delays or batch processing

## Key Features

### Request-Based Flow

Instead of immediate deposits/withdrawals, users follow a 3-step process:

1. **Request** - User initiates deposit/redemption request
2. **Pending** - Request is queued and waiting to be fulfilled
3. **Claimable** - Operator fulfills the request
4. **Claimed** - User claims their shares/assets

### Dual Async Support

This implementation supports both:
- ✅ Asynchronous deposits (`requestDeposit`)
- ✅ Asynchronous redemptions (`requestRedeem`)

### Operator System

- Controllers can approve operators to manage requests on their behalf
- Useful for smart contract integrations and automation

## Architecture

```
User Flow (Deposit):
┌──────────────┐
│ 1. Request   │ → User calls requestDeposit()
│   Deposit    │   Assets transferred to vault
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ 2. Pending   │ → Request waits in queue
│   State      │   pendingDepositRequest[user] += amount
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ 3. Fulfill   │ → Operator calls fulfillDeposit()
│   Request    │   Moves to claimable state
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ 4. Claim     │ → User calls deposit() or mint()
│   Shares     │   Receives vault shares
└──────────────┘
```

## Installation

### Using Foundry

```bash
forge install OpenZeppelin/openzeppelin-contracts
```

### Using Hardhat

```bash
npm install @openzeppelin/contracts
```

## Contract Structure

### Main Contract: `ERC7540Vault.sol`

```solidity
contract ERC7540Vault is ERC20, ERC165, IERC4626
```

#### Key State Variables

```solidity
// Operator approvals
mapping(address => mapping(address => bool)) public isOperator;

// Deposit tracking
mapping(address => uint256) public pendingDepositRequest;
mapping(address => uint256) public claimableDepositRequest;

// Redemption tracking
mapping(address => uint256) public pendingRedeemRequest;
mapping(address => uint256) public claimableRedeemRequest;
```

#### Core Functions

**Request Functions:**
- `requestDeposit(assets, controller, owner)` - Request async deposit
- `requestRedeem(shares, controller, owner)` - Request async redemption

**View Functions:**
- `pendingDepositRequest(requestId, controller)` - Check pending deposits
- `claimableDepositRequest(requestId, controller)` - Check claimable deposits
- `pendingRedeemRequest(requestId, controller)` - Check pending redemptions
- `claimableRedeemRequest(requestId, controller)` - Check claimable redemptions

**Claim Functions:**
- `deposit(assets, receiver, controller)` - Claim deposit request
- `mint(shares, receiver, controller)` - Claim deposit request (by shares)
- `withdraw(assets, receiver, controller)` - Claim redemption request
- `redeem(shares, receiver, controller)` - Claim redemption request

**Operator Functions:**
- `setOperator(operator, approved)` - Approve/revoke operator
- `isOperator(controller, operator)` - Check operator status

**Fulfillment Functions (Operator Only):**
- `fulfillDeposit(controller, assets)` - Fulfill deposit request
- `fulfillRedeem(controller, shares)` - Fulfill redemption request
- `batchFulfillDeposits(controllers[], amounts[])` - Batch fulfill deposits
- `batchFulfillRedeems(controllers[], amounts[])` - Batch fulfill redemptions

## Usage Examples

### Example 1: Basic Async Deposit

```solidity
// Step 1: Approve vault to spend tokens
IERC20(asset).approve(address(vault), 1000e18);

// Step 2: Request deposit
uint256 requestId = vault.requestDeposit(1000e18, msg.sender, msg.sender);

// Step 3: Wait for operator to fulfill (off-chain)
// Operator calls: vault.fulfillDeposit(msg.sender, 1000e18)

// Step 4: Claim your shares
uint256 shares = vault.deposit(1000e18, msg.sender);
```

### Example 2: Basic Async Redemption

```solidity
// Step 1: Request redemption (shares are burned immediately)
uint256 requestId = vault.requestRedeem(shares, msg.sender, msg.sender);

// Step 2: Wait for operator to fulfill
// Operator calls: vault.fulfillRedeem(msg.sender, shares)

// Step 3: Claim your assets
uint256 assets = vault.redeem(shares, msg.sender);
```

### Example 3: Using Operators

```solidity
// User approves operator
vault.setOperator(operatorAddress, true);

// Operator can now request on behalf of user
vault.requestDeposit(1000e18, userAddress, userAddress);

// Operator can also claim on behalf of user
vault.deposit(1000e18, userAddress, userAddress);
```

### Example 4: Batch Fulfillment

```solidity
// Operator fulfills multiple requests at once
address[] memory controllers = new address[](3);
controllers[0] = user1;
controllers[1] = user2;
controllers[2] = user3;

uint256[] memory amounts = new uint256[](3);
amounts[0] = 1000e18;
amounts[1] = 2000e18;
amounts[2] = 1500e18;

vault.batchFulfillDeposits(controllers, amounts);
```

### Example 5: Partial Claims

```solidity
// Request 1000 tokens
vault.requestDeposit(1000e18, msg.sender, msg.sender);

// After fulfillment, claim only 500
vault.deposit(500e18, msg.sender);

// 500 still claimable
uint256 remaining = vault.claimableDepositRequest(0, msg.sender); // 500e18

// Claim the rest later
vault.deposit(500e18, msg.sender);
```

## Integration Guide

### For Frontend Developers

```javascript
// 1. Check if user has pending requests
const pending = await vault.pendingDepositRequest(0, userAddress);

// 2. Check if user has claimable requests
const claimable = await vault.claimableDepositRequest(0, userAddress);

// 3. Request deposit
const tx = await asset.approve(vault.address, amount);
await tx.wait();
const requestTx = await vault.requestDeposit(amount, userAddress, userAddress);
await requestTx.wait();

// 4. Monitor for fulfillment
vault.on("RequestFulfilled", (controller, isDeposit, amount) => {
  if (controller === userAddress && isDeposit) {
    console.log("Deposit ready to claim!");
  }
});

// 5. Claim shares
const claimTx = await vault.deposit(amount, userAddress);
await claimTx.wait();
```

### For Smart Contract Integrators

```solidity
contract VaultIntegration {
    ERC7540Vault public vault;
    
    function depositAndWait(uint256 assets) external {
        // Approve and request
        IERC20(vault.asset()).transferFrom(msg.sender, address(this), assets);
        IERC20(vault.asset()).approve(address(vault), assets);
        vault.requestDeposit(assets, address(this), address(this));
        
        // Store request info for later claim
        // Implementation specific...
    }
    
    function claimWhenReady() external {
        uint256 claimable = vault.claimableDepositRequest(0, address(this));
        if (claimable > 0) {
            vault.deposit(claimable, msg.sender);
        }
    }
}
```

## Important Considerations

### 1. Preview Functions Revert

Per EIP-7540 spec, preview functions (`previewDeposit`, `previewMint`, `previewWithdraw`, `previewRedeem`) **MUST revert** for async flows because:
- Exchange rate is unknown until fulfillment
- Cannot preview async operations

### 2. No Short-Circuiting

Requests **cannot** skip the claimable state. Even if a request could be fulfilled immediately, users must:
1. Call `requestDeposit`/`requestRedeem`
2. Wait for `fulfillDeposit`/`fulfillRedeem`
3. Call `deposit`/`redeem`

### 3. Request IDs

This implementation uses `requestId = 0` for simplicity. This means:
- All requests for the same controller are aggregated
- Cannot discriminate between individual requests
- Suitable for most use cases

For advanced use cases requiring unique request tracking, implement non-zero request IDs.

### 4. Exchange Rate Changes

The exchange rate between request and claim **can change**:
- Yield may accrue
- Vault may have losses
- Implementation determines the final rate

### 5. Share Burning on Redemption

Per spec, shares are **burned immediately** on `requestRedeem`:
- Prevents double-spending
- User no longer has shares
- Assets returned on claim

## ERC-165 Interface Support

The vault implements ERC-165 and returns `true` for:

```solidity
0xe3bc4e65 // ERC7540 operator methods
0x2f0a18c5 // ERC7575 interface
0xce3bbe50 // Async deposit support
0x620ee8e4 // Async redemption support
```

Check support:
```solidity
bool supportsAsyncDeposit = vault.supportsInterface(0xce3bbe50);
bool supportsAsyncRedeem = vault.supportsInterface(0x620ee8e4);
```

## Security Considerations

### 1. Operator Trust

- Operators have significant control over requests
- Only approve trusted addresses as operators
- Operators can claim shares/assets to any receiver

### 2. Fulfillment Delays

- Implement appropriate delays to prevent front-running
- This implementation uses configurable `fulfillmentDelay`
- Consider your specific use case requirements

### 3. Exchange Rate Manipulation

- Vault operators control when requests are fulfilled
- Fulfillment timing affects exchange rates
- Implement safeguards for fair pricing

### 4. Pending Request Risks

- Assets in pending state are locked
- No cancellation mechanism in this basic implementation
- Consider adding cancellation for production use

### 5. Reentrancy

- Standard reentrancy guards should be added for production
- Consider using OpenZeppelin's `ReentrancyGuard`

## Testing

Run tests with Foundry:

```bash
forge test
```

Run tests with Hardhat:

```bash
npx hardhat test
```

## Gas Optimization Tips

1. **Batch Operations**: Use batch fulfillment for multiple users
2. **Partial Claims**: Allow users to claim incrementally
3. **Request Aggregation**: Using `requestId = 0` reduces storage costs
4. **Event Indexing**: Monitor events off-chain to reduce view call costs

## Deployment

```solidity
constructor(
    IERC20 asset_,           // Underlying asset token
    string memory name_,     // Vault token name
    string memory symbol_,   // Vault token symbol
    address operator_,       // Address that can fulfill requests
    uint256 fulfillmentDelay_ // Minimum delay before fulfillment (seconds)
)
```

Example:
```solidity
ERC7540Vault vault = new ERC7540Vault(
    IERC20(USDC),
    "Async USDC Vault",
    "aUSDC",
    operatorAddress,
    1 hours
);
```

## License

MIT

## Resources

- [EIP-7540 Specification](https://eips.ethereum.org/EIPS/eip-7540)
- [EIP-4626 Specification](https://eips.ethereum.org/EIPS/eip-4626)
- [OpenZeppelin ERC4626](https://docs.openzeppelin.com/contracts/4.x/erc4626)

## Contributing

Contributions are welcome! Please consider:
- Adding cancellation functionality
- Implementing non-zero request IDs
- Adding more sophisticated fulfillment logic
- Improving gas efficiency
- Adding more test cases

## Disclaimer

This implementation is for educational purposes. Audit thoroughly before production use.
