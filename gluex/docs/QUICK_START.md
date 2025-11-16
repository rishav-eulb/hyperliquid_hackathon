# HyperYield Optimizer - Quick Start Guide

## For Hackathon Judges & Reviewers

This guide will help you quickly set up and test the HyperYield Optimizer project.

---

## ⚡ 5-Minute Quick Start

### Prerequisites

Ensure you have:
- Node.js 18+ installed
- Python 3.9+ installed
- Git installed
- A code editor (VS Code recommended)

### Step 1: Clone and Install (2 minutes)

```bash
# Clone the repository
git clone https://github.com/yourusername/hyperliquid-yield-optimizer
cd hyperliquid-yield-optimizer

# Install all dependencies
npm run install:all

# This runs:
# - cd contracts && forge install
# - cd backend && pip install -r requirements.txt
# - cd frontend && npm install
```

### Step 2: Configure (1 minute)

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your values
# Minimum required:
# - GLUEX_API_KEY (get from https://portal.gluex.xyz)
# - GLUEX_API_SECRET
```

### Step 3: Run Tests (1 minute)

```bash
# Test smart contracts
cd contracts && forge test -vv

# Test backend
cd backend && pytest tests/ -v

# Test frontend
cd frontend && npm test
```

### Step 4: View Demo (1 minute)

```bash
# Start frontend with mock data
cd frontend && npm run dev

# Open http://localhost:3000
```

---

## 📋 Complete Setup Guide

### Part 1: Development Environment

#### Install Foundry (Smart Contracts)

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
forge --version  # Verify installation
```

#### Install Python Dependencies

```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

#### Install Node Dependencies

```bash
cd frontend
npm install
```

### Part 2: GlueX API Setup

1. **Register on GlueX Portal**
   - Visit: https://portal.gluex.xyz
   - Create account
   - Generate API credentials

2. **Get API Keys**
   - Navigate to API section
   - Click "Create New Key"
   - Copy API Key and Secret
   - Save them securely

3. **Add to Environment**
   ```bash
   GLUEX_API_KEY=your_key_here
   GLUEX_API_SECRET=your_secret_here
   ```

### Part 3: HyperEVM Configuration

1. **Get Testnet Access**
   - Visit Hyperliquid Discord
   - Request testnet access
   - Get testnet RPC URL

2. **Create Test Wallet**
   ```bash
   # Generate new wallet (or use existing)
   cast wallet new
   
   # Save the private key
   PRIVATE_KEY=0x...
   ```

3. **Get Testnet USDC**
   - Use Hyperliquid faucet
   - Or bridge from other testnet

### Part 4: Smart Contract Deployment

#### Option A: Local Testing (Recommended for Demo)

```bash
cd contracts

# Start local node
anvil

# In another terminal, deploy
forge script script/Deploy.s.sol:DeployScript \
  --fork-url http://localhost:8545 \
  --broadcast
```

#### Option B: HyperEVM Testnet

```bash
cd contracts

# Deploy to testnet
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $HYPEREVM_RPC_URL \
  --broadcast \
  --verify

# Save deployed addresses
echo "VAULT_ADDRESS=0x..." >> ../.env
echo "MANAGER_ADDRESS=0x..." >> ../.env
```

### Part 5: Running the Services

#### Terminal 1: Optimizer Bot

```bash
cd backend
source venv/bin/activate
python optimizer.py
```

You should see:
```
🚀 HyperYield Optimizer started
Check interval: 300s
Min APY difference: 0.5%
Optimization strategy: sharpe
===========================================================
```

#### Terminal 2: Frontend

```bash
cd frontend
npm run dev
```

Open http://localhost:3000

---

## 🧪 Testing Guide

### Smart Contract Tests

#### Run All Tests

```bash
cd contracts
forge test -vv
```

#### Run Specific Test

```bash
forge test --match-test testDepositFlow -vvv
```

#### Test Coverage

```bash
forge coverage
```

#### Expected Output

```
Running 15 tests for test/HyperYieldVault.t.sol:HyperYieldVaultTest
[PASS] testDepositRequest() (gas: 125432)
[PASS] testClaimDeposit() (gas: 178934)
[PASS] testRedeemRequest() (gas: 134562)
[PASS] testClaimRedeem() (gas: 189765)
[PASS] testShareLockPeriod() (gas: 145678)
...
Test result: ok. 15 passed; 0 failed; finished in 3.45s
```

### Backend Tests

#### Run All Tests

```bash
cd backend
pytest tests/ -v
```

#### Run with Coverage

```bash
pytest tests/ --cov=. --cov-report=html
```

#### Test Specific Module

```bash
pytest tests/test_gluex_client.py -v
```

#### Expected Output

```
tests/test_gluex_client.py::test_get_historical_apy PASSED
tests/test_gluex_client.py::test_get_diluted_apy PASSED
tests/test_gluex_client.py::test_calculate_sharpe_ratio PASSED
tests/test_optimizer.py::test_should_rebalance PASSED
tests/test_optimizer.py::test_find_best_opportunity PASSED
=============================== 12 passed in 5.23s ===============================
```

### Integration Tests

#### Run End-to-End Tests

```bash
npm run test:integration
```

#### Manual Integration Test

1. **Start all services**
   ```bash
   # Terminal 1
   cd backend && python optimizer.py
   
   # Terminal 2
   cd frontend && npm run dev
   ```

2. **Open frontend**
   - Navigate to http://localhost:3000

3. **Connect wallet**
   - Click "Connect Wallet"
   - Use MetaMask with test account

4. **Deposit USDC**
   - Enter amount: 1000
   - Click "Deposit"
   - Approve transaction
   - Wait for confirmation

5. **Verify deposit**
   - Check vault balance
   - Verify shares received
   - Confirm lock period

6. **Monitor rebalancing**
   - Watch backend logs
   - Wait for next cycle (5 minutes)
   - Verify rebalancing occurs if better opportunity exists

7. **Withdraw**
   - Request redemption
   - Wait for async processing
   - Claim assets
   - Verify USDC received

---

## 🐛 Troubleshooting

### Common Issues

#### Issue 1: "GlueX API Key Invalid"

**Solution:**
```bash
# Verify API key format
echo $GLUEX_API_KEY

# Should be alphanumeric, 32+ characters
# Regenerate if needed at portal.gluex.xyz
```

#### Issue 2: "Insufficient Balance"

**Solution:**
```bash
# Check wallet balance
cast balance $YOUR_ADDRESS --rpc-url $HYPEREVM_RPC_URL

# Get testnet USDC from faucet
```

#### Issue 3: "Transaction Reverted"

**Solution:**
```bash
# Check gas limit
# Increase in transaction

# Check contract state
cast call $VAULT_ADDRESS "paused()" --rpc-url $HYPEREVM_RPC_URL

# Unpause if needed (owner only)
```

#### Issue 4: "Bot Not Rebalancing"

**Solution:**
```bash
# Check cooldown period
cast call $MANAGER_ADDRESS "canRebalance()" --rpc-url $HYPEREVM_RPC_URL

# Check APY difference
# Must exceed MIN_APY_DIFF (default 0.5%)

# Verify bot authorization
cast call $MANAGER_ADDRESS "authorizedBots(address)(bool)" $BOT_ADDRESS --rpc-url $HYPEREVM_RPC_URL
```

#### Issue 5: "Frontend Not Loading"

**Solution:**
```bash
# Clear Next.js cache
cd frontend
rm -rf .next
npm run dev

# Check port availability
lsof -i :3000  # Kill if occupied
```

---

## 📊 Verification Checklist

Use this checklist to verify the project meets all requirements:

### ✅ Core Requirements

- [ ] ERC-7540 or BoringVault for custody
- [ ] GlueX Yields API integration
- [ ] GlueX Router API integration
- [ ] GlueX Vaults included in whitelist
- [ ] Automated rebalancing logic
- [ ] Smart contracts deployed
- [ ] Backend service running
- [ ] Frontend interface working

### ✅ Technical Requirements

- [ ] Async deposit flow implemented
- [ ] Async redemption flow implemented
- [ ] Share lock period active (1 day)
- [ ] Whitelist management functional
- [ ] Rebalancing cooldown enforced (1 hour)
- [ ] Sharpe ratio calculation accurate
- [ ] Gas optimization implemented
- [ ] Error handling robust

### ✅ Security Requirements

- [ ] Access control implemented
- [ ] Emergency pause functional
- [ ] Non-custodial architecture
- [ ] No flash loan vulnerabilities
- [ ] Input validation present
- [ ] Reentrancy protection active

### ✅ Documentation

- [ ] README with setup instructions
- [ ] Technical documentation complete
- [ ] Demo video (<3 minutes)
- [ ] Code comments present
- [ ] API documentation included

---

## 🎥 Demo Video Guidelines

### Recording Setup

1. **Screen Resolution**: 1920x1080 minimum
2. **Frame Rate**: 60fps
3. **Audio**: Clear narration, no background noise
4. **Duration**: Under 3 minutes

### Content Structure

```
00:00-00:20  Introduction & Problem
00:20-00:40  Solution Overview
00:40-01:20  Architecture Explanation
01:20-02:00  Live Demo (Deposit → Rebalance → Withdraw)
02:00-02:30  Results & Benefits
02:30-03:00  Call to Action & Links
```

### Recording Tools

- **Screen Recording**: OBS Studio, Loom, or ScreenFlow
- **Audio**: Blue Yeti mic or similar
- **Editing**: DaVinci Resolve (free) or Adobe Premiere
- **Cursor Highlighting**: Cursor Highlighter extension

### Demo Script

See `docs/DEMO_SCRIPT.md` for detailed walkthrough.

---

## 📈 Performance Benchmarks

Expected performance metrics:

| Metric | Value |
|--------|-------|
| Deposit Gas | ~150,000 gas |
| Redeem Gas | ~180,000 gas |
| Rebalance Gas | ~300,000 gas |
| Optimizer Cycle Time | 5-10 seconds |
| API Response Time | <500ms |
| Frontend Load Time | <2 seconds |

---

## 🔗 Useful Links

- **GlueX Portal**: https://portal.gluex.xyz
- **GlueX Docs**: https://docs.gluex.xyz
- **Hyperliquid Docs**: https://hyperliquid.gitbook.io
- **ERC-7540 Spec**: https://eips.ethereum.org/EIPS/eip-7540
- **Foundry Book**: https://book.getfoundry.sh

---

## 💬 Support

For issues or questions:

1. Check this documentation first
2. Review `docs/TECHNICAL_DOCUMENTATION.md`
3. Open a GitHub issue
4. Contact via Discord (link in README)

---

## 🏆 Hackathon Submission Checklist

Before submitting:

- [ ] All code pushed to GitHub
- [ ] README updated with latest info
- [ ] Demo video uploaded and linked
- [ ] Contracts deployed to testnet
- [ ] Contract addresses documented
- [ ] .env.example updated
- [ ] All tests passing
- [ ] Documentation complete
- [ ] Screenshots/GIFs included
- [ ] License file present

---

## 📝 Evaluation Criteria

Remember, judges will evaluate on:

1. **Impact & Ecosystem Fit** (25%)
   - Solves real problem
   - Benefits HyperEVM ecosystem
   - Uses GlueX integration effectively

2. **Execution & User Experience** (25%)
   - Clean, intuitive interface
   - Smooth user flows
   - Professional polish

3. **Technical Creativity & Design** (25%)
   - Innovative architecture
   - ERC-7540 implementation
   - Optimal algorithm design

4. **Completeness & Demo Quality** (25%)
   - All requirements met
   - Clear demonstration
   - Working prototype

Good luck! 🚀
