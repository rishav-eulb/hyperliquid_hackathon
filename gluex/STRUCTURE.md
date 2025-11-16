# Project Structure - Quick Reference

## 📁 Directory Layout

```
gluex/
│
├── 📄 README.md                    ← Start here!
├── 🔧 foundry.toml                 ← Foundry config
├── 📦 package.json                 ← Node.js config
├── ⚙️  setup.sh                     ← One-command setup
├── 📝 env.template                 ← Environment template
│
├── 📘 contracts/                   ← Smart Contracts (Solidity)
│   ├── HyperYieldVault.sol        ← Main vault contract
│   ├── VaultManager.sol            ← Rebalancing manager
│   └── interfaces/                 ← Contract interfaces
│       ├── IERC4626.sol
│       ├── IERC7540.sol
│       └── IGlueXRouter.sol
│
├── 🚀 scripts/                     ← Deployment Scripts
│   └── Deploy.s.sol                ← Main deployment
│
├── 🐍 backend/                     ← Python Backend
│   ├── optimizer.py                ← Main bot logic
│   ├── gluex_client.py             ← GlueX API client
│   ├── requirements.txt            ← Python dependencies
│   └── __init__.py                 ← Package init
│
├── 🎨 pages/                       ← Next.js Pages
│   ├── index.js                    ← Home page
│   └── _app.js                     ← App wrapper
│
├── 💅 styles/                      ← CSS Styles
│   └── globals.css                 ← Global styles
│
├── 🖼️  public/                      ← Static Assets
│
├── 📚 docs/                        ← Documentation
│   ├── ARCHITECTURE.md             ← System design
│   ├── TECHNICAL_DOCUMENTATION.md  ← Technical details
│   ├── QUICK_START.md              ← Getting started
│   ├── DEMO_SCRIPT.md              ← Demo guide
│   ├── FIXES.md                    ← Bug fixes log
│   ├── CHANGELOG.md                ← Version history
│   └── RESTRUCTURING.md            ← This reorganization
│
└── 🧪 test/                        ← Tests (future)
```

---

## 🎯 Quick Navigation

### Working with Contracts
```bash
# Location
cd contracts/

# Compile
forge build

# Deploy
forge script scripts/Deploy.s.sol --rpc-url $HYPEREVM_RPC_URL --broadcast
```

### Working with Backend
```bash
# Location
cd backend/

# Run optimizer
source ../venv/bin/activate
python optimizer.py

# Test API client
python gluex_client.py
```

### Working with Frontend
```bash
# Location (root directory)

# Install deps
npm install

# Run dev server
npm run dev

# Build for production
npm run build
```

### Reading Documentation
```bash
# Location
cd docs/

# Quick start
cat QUICK_START.md

# Architecture
cat ARCHITECTURE.md

# All changes
cat CHANGELOG.md
```

---

## 🔍 Find Files Fast

### Smart Contracts
| File | Location | Purpose |
|------|----------|---------|
| Main Vault | `contracts/HyperYieldVault.sol` | ERC-7540 async vault |
| Manager | `contracts/VaultManager.sol` | Rebalancing logic |
| ERC4626 Interface | `contracts/interfaces/IERC4626.sol` | Vault standard |
| ERC7540 Interface | `contracts/interfaces/IERC7540.sol` | Async vault standard |
| Router Interface | `contracts/interfaces/IGlueXRouter.sol` | GlueX router |
| Deployment | `scripts/Deploy.s.sol` | Deploy script |

### Python Backend
| File | Location | Purpose |
|------|----------|---------|
| Main Bot | `backend/optimizer.py` | Optimization bot |
| API Client | `backend/gluex_client.py` | GlueX API integration |
| Dependencies | `backend/requirements.txt` | Python packages |

### Frontend
| File | Location | Purpose |
|------|----------|---------|
| Main Component | `App.jsx` | Dashboard UI |
| Home Page | `pages/index.js` | Next.js entry |
| App Wrapper | `pages/_app.js` | Next.js config |
| Styles | `styles/globals.css` | Global CSS |

### Documentation
| File | Location | Purpose |
|------|----------|---------|
| Main README | `README.md` | Project overview |
| Architecture | `docs/ARCHITECTURE.md` | System design |
| Quick Start | `docs/QUICK_START.md` | Getting started |
| Technical Docs | `docs/TECHNICAL_DOCUMENTATION.md` | Deep dive |
| Fixes Log | `docs/FIXES.md` | Bug fixes |
| Changelog | `docs/CHANGELOG.md` | Version history |
| Restructuring | `docs/RESTRUCTURING.md` | This change |

---

## 🚀 Common Commands

### Setup
```bash
./setup.sh                          # Install everything
cp env.template .env                # Configure environment
```

### Development
```bash
forge build                         # Compile contracts
forge test                          # Run contract tests
npm run dev                         # Start frontend
python backend/optimizer.py         # Run optimizer bot
```

### Deployment
```bash
forge script scripts/Deploy.s.sol --rpc-url $HYPEREVM_RPC_URL --broadcast
```

### Verification
```bash
# Check structure
find . -type d -maxdepth 2 | grep -v node_modules

# Find contracts
find contracts -name "*.sol"

# Find Python files
find backend -name "*.py"
```

---

## 💡 Tips

1. **Start with README.md** - Everything you need to know
2. **Use setup.sh** - Automates all setup
3. **Check docs/** - Detailed documentation
4. **Follow .gitignore** - Don't commit build artifacts
5. **Use env.template** - Never commit secrets

---

## 🏗️ Build Artifacts

These directories are auto-generated (ignored by git):

```
gluex/
├── out/           ← Compiled contracts
├── cache/         ← Forge cache
├── lib/           ← Installed dependencies
├── node_modules/  ← Node packages
└── venv/          ← Python virtual environment
```

---

## 📊 File Count

- **Contracts:** 5 (.sol files)
- **Scripts:** 1 (Deploy.s.sol)
- **Backend:** 3 (.py files)
- **Frontend:** 7+ files
- **Documentation:** 8+ (.md files)
- **Config:** 6 files

**Total:** ~35 organized files

---

## ✨ Structure Benefits

✅ **Clear Organization** - Easy to find anything
✅ **Industry Standard** - Follows conventions
✅ **Scalable** - Room to grow
✅ **Tool Support** - Works with all tools
✅ **Team Friendly** - Easy for new developers

---

**Last Updated:** 2025-11-16  
**Version:** 1.1.0 (Restructured)

