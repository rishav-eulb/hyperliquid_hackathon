# HyperYield Optimizer

**A decentralized yield optimization protocol for HyperEVM leveraging GlueX APIs**

## 🎯 Overview

HyperYield Optimizer is an intelligent yield optimization protocol that automatically reallocates user funds across the highest-yielding opportunities on HyperEVM. Built for the Hyperliquid Community Hackathon, it combines ERC-7540 async vault standard with GlueX's powerful APIs to deliver optimal risk-adjusted returns.

### Key Features

- ✅ **ERC-7540 Compliant Vault** - Async deposit/redemption with institutional-grade security
- ✅ **Automated Yield Optimization** - Real-time monitoring of APY across whitelisted vaults
- ✅ **GlueX Integration** - Uses Yields API for discovery and Router API for execution
- ✅ **Risk Management** - Sharpe ratio optimization for best risk-adjusted returns
- ✅ **Transparent Operations** - All rebalancing actions are on-chain and auditable
- ✅ **Gas Efficient** - Batched operations minimize transaction costs

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     HyperYield Optimizer                     │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────┐        ┌──────────────────┐           │
│  │  ERC-7540 Vault  │◄──────►│  Vault Manager   │           │
│  │  (On-Chain)      │        │  (On-Chain)      │           │
│  └──────────────────┘        └──────────────────┘           │
│           │                           │                       │
│           │                           │                       │
│           ▼                           ▼                       │
│  ┌──────────────────┐        ┌──────────────────┐           │
│  │  Optimizer Bot   │◄──────►│  GlueX Router    │           │
│  │  (Off-Chain)     │        │  API             │           │
│  └──────────────────┘        └──────────────────┘           │
│           │                           │                       │
│           ▼                           ▼                       │
│  ┌──────────────────┐        ┌──────────────────┐           │
│  │  GlueX Yields    │        │  Whitelisted     │           │
│  │  API             │        │  Vaults          │           │
│  └──────────────────┘        └──────────────────┘           │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## 📦 Project Structure

```
gluex/
├── contracts/                    # Smart Contracts
│   ├── HyperYieldVault.sol      # ERC-7540 vault implementation
│   ├── VaultManager.sol          # Whitelist & rebalancing logic
│   └── interfaces/
│       ├── IERC7540.sol         # ERC-7540 interface
│       ├── IERC4626.sol         # ERC-4626 interface
│       └── IGlueXRouter.sol     # GlueX Router interface
├── scripts/                      # Deployment Scripts
│   └── Deploy.s.sol             # Foundry deployment script
├── backend/                      # Python Backend
│   ├── optimizer.py             # Main optimizer bot logic
│   ├── gluex_client.py          # GlueX API client
│   └── requirements.txt         # Python dependencies
├── pages/                        # Next.js Pages
│   ├── index.js                 # Main page
│   └── _app.js                  # Next.js app wrapper
├── styles/                       # CSS Styles
│   └── globals.css              # Global styles
├── public/                       # Static Assets
├── docs/                         # Documentation
│   ├── ARCHITECTURE.md          # System architecture
│   ├── TECHNICAL_DOCUMENTATION.md # Technical details
│   ├── QUICK_START.md           # Quick start guide
│   ├── DEMO_SCRIPT.md           # Demo walkthrough
│   ├── FIXES.md                 # Applied fixes log
│   └── CHANGELOG.md             # Version history
├── test/                         # Tests (to be added)
├── App.jsx                       # Dashboard component
├── foundry.toml                  # Foundry configuration
├── package.json                  # Node dependencies
├── next.config.js                # Next.js configuration
├── tailwind.config.js            # Tailwind CSS configuration
├── env.template                  # Environment template
├── setup.sh                      # Setup script
├── .gitignore                    # Git ignore rules
└── README.md                     # This file
```

## 🚀 Quick Start

### Prerequisites

- Node.js v18+
- Python 3.9+
- Foundry (for smart contracts)
- HyperEVM testnet access
- GlueX API credentials ([Get them here](https://portal.gluex.xyz))

### Installation

#### Quick Setup (Recommended)

Run the automated setup script:
```bash
chmod +x setup.sh
./setup.sh
```

This will automatically install:
- OpenZeppelin contracts
- Forge Standard Library
- Python dependencies (in virtual environment)
- Node.js dependencies

#### Manual Setup

If you prefer to install dependencies manually:

1. **Install Foundry dependencies**
```bash
forge install OpenZeppelin/openzeppelin-contracts@v4.9.3 --no-commit
forge install foundry-rs/forge-std --no-commit
```

2. **Install Python dependencies**
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

3. **Install Node.js dependencies**
```bash
npm install
```

### Configuration

1. **Set up environment variables**
```bash
# Create .env file from template
cp env.template .env
```

2. **Configure your .env file**
```env
# Blockchain
HYPEREVM_RPC_URL=https://api.hyperliquid-testnet.xyz/evm
PRIVATE_KEY=your_private_key_here

# GlueX API
GLUEX_API_KEY=your_gluex_api_key
GLUEX_API_SECRET=your_gluex_secret

# Contract Addresses (after deployment)
VAULT_ADDRESS=
MANAGER_ADDRESS=

# Optimizer Settings
CHECK_INTERVAL=300  # 5 minutes
MIN_APY_DIFF=0.5    # 0.5% minimum difference to trigger rebalance
```

### Deployment

1. **Deploy smart contracts**
```bash
forge script scripts/Deploy.s.sol:DeployScript --rpc-url $HYPEREVM_RPC_URL --broadcast
```

2. **Update .env with deployed addresses**

3. **Start the optimizer backend**
```bash
source venv/bin/activate
python backend/optimizer.py
```

4. **Start the frontend**
```bash
npm run dev
```

5. **Access the app at** `http://localhost:3000`

## 🔧 How It Works

### 1. Deposit Flow

1. User deposits USDC into the HyperYield Vault
2. Vault issues async deposit request (ERC-7540)
3. Request becomes claimable after processing
4. User receives vault shares representing their position

### 2. Yield Monitoring

The optimizer backend continuously:
- Queries GlueX Yields API for APY data across whitelisted vaults
- Calculates risk-adjusted returns (Sharpe ratio)
- Identifies optimal reallocation opportunities
- Triggers rebalancing when threshold is exceeded

### 3. Rebalancing Flow

When a better yield opportunity is identified:
1. Optimizer calls VaultManager to initiate rebalance
2. VaultManager withdraws from current vault
3. Uses GlueX Router API to get optimal swap route
4. Executes swap and deposits into new vault
5. Emits rebalancing event for transparency

### 4. Withdrawal Flow

1. User requests redemption (async)
2. Shares are locked during request period
3. Vault processes withdrawal from underlying positions
4. User claims assets after cooling period

## 📊 Whitelisted GlueX Vaults

The protocol includes the following GlueX vaults:

| Vault Address | Description |
|---------------|-------------|
| `0xe25514992597786e07872e6c5517fe1906c0cadd` | GlueX Vault 1 |
| `0xcdc3975df9d1cf054f44ed238edfb708880292ea` | GlueX Vault 2 |
| `0x8f9291606862eef771a97e5b71e4b98fd1fa216a` | GlueX Vault 3 |
| `0x9f75eac57d1c6f7248bd2aede58c95689f3827f7` | GlueX Vault 4 |
| `0x63cf7ee583d9954febf649ad1c40c97a6493b1be` | GlueX Vault 5 |

## 🔐 Security Features

- **Async Vault Pattern**: ERC-7540 prevents flash loan attacks
- **Whitelist Control**: Only approved vaults can receive funds
- **Multi-sig Manager**: Critical operations require multiple signatures
- **Rate Limiting**: Prevents excessive rebalancing
- **Emergency Pause**: Circuit breaker for unforeseen issues
- **Audited Code**: Following OpenZeppelin best practices

## 🧪 Testing

### Smart Contracts
```bash
cd contracts
forge test -vv
```

### Backend
```bash
cd backend
pytest tests/
```

### Frontend
```bash
cd frontend
npm test
```

### Integration Tests
```bash
npm run test:integration
```

## 📈 Performance Metrics

Track optimizer performance through:
- **Total Value Locked (TVL)**
- **Current APY**
- **Historical Returns**
- **Sharpe Ratio**
- **Rebalancing History**
- **Gas Costs**

## 🎥 Demo

Watch our 3-minute demo video: [Link to demo video]

Demo walkthrough:
1. User deposits $1,000 USDC
2. Funds allocated to highest APY vault (12.5%)
3. Better opportunity detected (15.2% APY)
4. Automatic rebalancing executed
5. User withdraws with optimized returns

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## 📄 License

MIT License - see [LICENSE](LICENSE) for details

## 👥 Team

Built with ❤️ for the Hyperliquid Community Hackathon

## 🙏 Acknowledgments

- **GlueX Protocol** - For providing excellent APIs
- **Hyperliquid** - For the amazing infrastructure
- **Chorus One** - For mentorship and guidance

## 📞 Support

- Documentation: [Full docs](./docs)
- Issues: [GitHub Issues](https://github.com/yourusername/hyperliquid-yield-optimizer/issues)
- Discord: [Join our channel](https://discord.gg/hyperliquid)

---

**Built for Hyperliquid Community Hackathon 2025**

**Bounty: GlueX Yield Optimization Challenge ($3,000)**
