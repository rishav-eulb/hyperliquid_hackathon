import React, { useState, useEffect } from 'react';
import { TrendingUp, Shield, Zap, DollarSign, ArrowRight, RefreshCw } from 'lucide-react';

// Main Dashboard Component
export default function Dashboard() {
  const [vaultData, setVaultData] = useState({
    totalDeposited: 0,
    currentAPY: 0,
    lifetimeEarnings: 0,
    currentVault: '',
    rebalanceCount: 0
  });

  const [vaultOpportunities, setVaultOpportunities] = useState([
    { address: '0xe25514992597786e07872e6c5517fe1906c0cadd', apy: 12.5, tvl: 5200000, risk: 'Low', sharpe: 2.1 },
    { address: '0xcdc3975df9d1cf054f44ed238edfb708880292ea', apy: 15.2, tvl: 3800000, risk: 'Medium', sharpe: 2.4 },
    { address: '0x8f9291606862eef771a97e5b71e4b98fd1fa216a', apy: 18.7, tvl: 2100000, risk: 'Medium', sharpe: 2.0 },
    { address: '0x9f75eac57d1c6f7248bd2aede58c95689f3827f7', apy: 10.8, tvl: 8500000, risk: 'Low', sharpe: 2.3 },
    { address: '0x63cf7ee583d9954febf649ad1c40c97a6493b1be', apy: 14.3, tvl: 4600000, risk: 'Low', sharpe: 2.6 }
  ]);

  const [depositAmount, setDepositAmount] = useState('');
  const [isDepositing, setIsDepositing] = useState(false);

  const handleDeposit = async () => {
    setIsDepositing(true);
    // Simulate deposit
    setTimeout(() => {
      setVaultData(prev => ({
        ...prev,
        totalDeposited: prev.totalDeposited + parseFloat(depositAmount || '0')
      }));
      setIsDepositing(false);
      setDepositAmount('');
    }, 2000);
  };

  const formatCurrency = (value) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 2
    }).format(value);
  };

  const formatAddress = (addr) => {
    return `${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}`;
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
      {/* Header */}
      <header className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4 py-6 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center">
            <div>
              <h1 className="text-3xl font-bold text-gray-900">HyperYield Optimizer</h1>
              <p className="text-sm text-gray-600 mt-1">Automated yield optimization on HyperEVM</p>
            </div>
            <button className="bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700 transition">
              Connect Wallet
            </button>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 py-8 sm:px-6 lg:px-8">
        {/* Stats Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <StatCard
            icon={<DollarSign className="w-6 h-6" />}
            title="Total Deposited"
            value={formatCurrency(vaultData.totalDeposited)}
            color="blue"
          />
          <StatCard
            icon={<TrendingUp className="w-6 h-6" />}
            title="Current APY"
            value={`${vaultData.currentAPY.toFixed(2)}%`}
            color="green"
          />
          <StatCard
            icon={<Zap className="w-6 h-6" />}
            title="Lifetime Earnings"
            value={formatCurrency(vaultData.lifetimeEarnings)}
            color="yellow"
          />
          <StatCard
            icon={<RefreshCw className="w-6 h-6" />}
            title="Rebalances"
            value={vaultData.rebalanceCount}
            color="purple"
          />
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Deposit Section */}
          <div className="lg:col-span-1">
            <div className="bg-white rounded-xl shadow-lg p-6">
              <h2 className="text-xl font-bold text-gray-900 mb-4">Deposit USDC</h2>
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Amount
                  </label>
                  <input
                    type="number"
                    value={depositAmount}
                    onChange={(e) => setDepositAmount(e.target.value)}
                    placeholder="0.00"
                    className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                  />
                </div>
                <button
                  onClick={handleDeposit}
                  disabled={isDepositing || !depositAmount}
                  className="w-full bg-indigo-600 text-white py-3 rounded-lg hover:bg-indigo-700 transition disabled:bg-gray-300 disabled:cursor-not-allowed font-medium"
                >
                  {isDepositing ? 'Processing...' : 'Deposit'}
                </button>
                <div className="bg-indigo-50 rounded-lg p-4">
                  <div className="flex items-start">
                    <Shield className="w-5 h-5 text-indigo-600 mt-0.5 mr-2 flex-shrink-0" />
                    <div className="text-sm text-indigo-900">
                      <p className="font-medium mb-1">ERC-7540 Protected</p>
                      <p className="text-indigo-700">Async deposits with 1-day lock period for security</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Vault Opportunities */}
          <div className="lg:col-span-2">
            <div className="bg-white rounded-xl shadow-lg p-6">
              <div className="flex justify-between items-center mb-6">
                <h2 className="text-xl font-bold text-gray-900">Whitelisted Vaults</h2>
                <span className="text-sm text-gray-500">Auto-optimizing for best Sharpe ratio</span>
              </div>
              <div className="space-y-3">
                {vaultOpportunities.map((vault, index) => (
                  <VaultCard key={index} vault={vault} formatAddress={formatAddress} />
                ))}
              </div>
            </div>
          </div>
        </div>

        {/* How It Works */}
        <div className="mt-8 bg-white rounded-xl shadow-lg p-8">
          <h2 className="text-2xl font-bold text-gray-900 mb-6 text-center">How It Works</h2>
          <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
            <Step
              number="1"
              title="Deposit USDC"
              description="Deposit your USDC into the HyperYield Vault"
            />
            <Step
              number="2"
              title="Monitor Yields"
              description="Bot monitors APYs across GlueX vaults every 5 minutes"
            />
            <Step
              number="3"
              title="Auto-Rebalance"
              description="When better opportunity found, automatically reallocates"
            />
            <Step
              number="4"
              title="Earn Optimized Returns"
              description="Enjoy best risk-adjusted returns with minimal effort"
            />
          </div>
        </div>
      </main>
    </div>
  );
}

// Stat Card Component
function StatCard({ icon, title, value, color }) {
  const colorClasses = {
    blue: 'bg-blue-100 text-blue-600',
    green: 'bg-green-100 text-green-600',
    yellow: 'bg-yellow-100 text-yellow-600',
    purple: 'bg-purple-100 text-purple-600'
  };

  return (
    <div className="bg-white rounded-xl shadow-lg p-6">
      <div className="flex items-center justify-between">
        <div className={`p-3 rounded-lg ${colorClasses[color]}`}>
          {icon}
        </div>
      </div>
      <h3 className="text-gray-600 text-sm font-medium mt-4">{title}</h3>
      <p className="text-2xl font-bold text-gray-900 mt-1">{value}</p>
    </div>
  );
}

// Vault Card Component
function VaultCard({ vault, formatAddress }) {
  const getRiskColor = (risk) => {
    switch (risk) {
      case 'Low': return 'bg-green-100 text-green-800';
      case 'Medium': return 'bg-yellow-100 text-yellow-800';
      case 'High': return 'bg-red-100 text-red-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  };

  return (
    <div className="border border-gray-200 rounded-lg p-4 hover:border-indigo-300 hover:shadow-md transition">
      <div className="flex justify-between items-start mb-3">
        <div>
          <p className="font-mono text-sm text-gray-600">{formatAddress(vault.address)}</p>
          <div className="flex items-center gap-2 mt-1">
            <span className={`text-xs px-2 py-1 rounded-full ${getRiskColor(vault.risk)}`}>
              {vault.risk} Risk
            </span>
          </div>
        </div>
        <div className="text-right">
          <p className="text-2xl font-bold text-indigo-600">{vault.apy}%</p>
          <p className="text-xs text-gray-500">APY</p>
        </div>
      </div>
      <div className="flex justify-between text-sm">
        <div>
          <p className="text-gray-600">TVL</p>
          <p className="font-medium">${(vault.tvl / 1000000).toFixed(1)}M</p>
        </div>
        <div>
          <p className="text-gray-600">Sharpe Ratio</p>
          <p className="font-medium">{vault.sharpe.toFixed(2)}</p>
        </div>
      </div>
    </div>
  );
}

// Step Component
function Step({ number, title, description }) {
  return (
    <div className="text-center">
      <div className="bg-indigo-600 text-white rounded-full w-12 h-12 flex items-center justify-center mx-auto mb-4 text-xl font-bold">
        {number}
      </div>
      <h3 className="font-bold text-gray-900 mb-2">{title}</h3>
      <p className="text-sm text-gray-600">{description}</p>
    </div>
  );
}
