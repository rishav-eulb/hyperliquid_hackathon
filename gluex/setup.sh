#!/bin/bash
# Setup script for HyperYield Optimizer
# This script installs all required dependencies for the project

set -e

echo "🚀 Setting up HyperYield Optimizer..."
echo ""

# Check if forge is installed
if ! command -v forge &> /dev/null; then
    echo "❌ Foundry not found. Please install Foundry first:"
    echo "   curl -L https://foundry.paradigm.xyz | bash"
    echo "   foundryup"
    exit 1
fi

echo "✅ Foundry found"
echo ""

# Install Solidity dependencies
echo "📦 Installing OpenZeppelin contracts..."
forge install OpenZeppelin/openzeppelin-contracts@v4.9.3 --no-commit

echo "📦 Installing Forge Standard Library..."
forge install foundry-rs/forge-std --no-commit

echo ""
echo "✅ Solidity dependencies installed"
echo ""

# Check if Python is installed
if command -v python3 &> /dev/null; then
    echo "📦 Installing Python dependencies..."
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "venv" ]; then
        python3 -m venv venv
        echo "✅ Created Python virtual environment"
    fi
    
    # Activate virtual environment and install dependencies
    source venv/bin/activate
    pip install -r backend/requirements.txt
    echo "✅ Python dependencies installed"
    echo ""
else
    echo "⚠️  Python3 not found. Skipping Python dependencies."
    echo "   Install Python 3.9+ to use the optimizer bot."
    echo ""
fi

# Check if Node.js is installed
if command -v npm &> /dev/null; then
    echo "📦 Installing Node.js dependencies..."
    npm install
    echo "✅ Node.js dependencies installed"
    echo ""
else
    echo "⚠️  npm not found. Skipping Node.js dependencies."
    echo "   Install Node.js 18+ to use the frontend."
    echo ""
fi

echo "✨ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Copy env.template to .env and configure your settings"
echo "   cp env.template .env"
echo "2. Deploy contracts:"
echo "   forge script scripts/Deploy.s.sol --rpc-url \$HYPEREVM_RPC_URL --broadcast"
echo "3. Start the optimizer bot:"
echo "   source venv/bin/activate"
echo "   python backend/optimizer.py"
echo "4. Start the frontend:"
echo "   npm run dev"
echo ""

