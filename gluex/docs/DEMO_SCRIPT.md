# HyperYield Optimizer - Demo Video Script

## Duration: 3 Minutes

---

## Scene 1: Introduction (0:00 - 0:25)

**[Screen: Landing Page with Logo Animation]**

**Narrator:**
"Introducing HyperYield Optimizer - an intelligent, automated yield optimization protocol for HyperEVM that maximizes your returns while you sleep."

**[Quick cuts showing:**
- Current APY: 15.2%
- Total Rebalances: 47
- Users Earning: 1,234
**]**

"Built for the Hyperliquid Community Hackathon, HyperYield combines ERC-7540 security with GlueX's powerful APIs to deliver optimal risk-adjusted returns."

---

## Scene 2: The Problem (0:25 - 0:45)

**[Screen: Split screen comparison]**

**Left side: Manual Management**
- User checking yields manually
- Multiple browser tabs open
- Confused expression
- Time wasted: 2 hours/day

**Right side: HyperYield**
- Automated monitoring
- Clean dashboard
- Happy user
- Time spent: 0 minutes

**Narrator:**
"APY volatility is huge in DeFi. Finding and capturing the best yields requires constant monitoring, technical knowledge, and perfect timing. Most users lose out on significant returns."

---

## Scene 3: The Solution (0:45 - 1:15)

**[Screen: Architecture Diagram Animation]**

**Narrator:**
"HyperYield Optimizer solves this with three key components:"

**[Component 1 highlights]**
"First, an ERC-7540 compliant vault ensures your funds are secure with asynchronous deposits and redemptions that prevent flash loan attacks."

**[Component 2 highlights]**
"Second, our Python bot continuously monitors yields across five whitelisted GlueX vaults, calculating Sharpe ratios to find the best risk-adjusted returns."

**[Component 3 highlights]**
"Third, when a better opportunity is found - automatically reallocate your funds using GlueX Router API for optimal execution."

---

## Scene 4: Live Demo - Deposit (1:15 - 1:45)

**[Screen: Dashboard Interface]**

**Narrator:**
"Let's see it in action. Meet Sarah - she has $10,000 USDC to invest."

**[Show wallet connection]**
- Click "Connect Wallet"
- MetaMask popup
- Wallet connected

**[Show deposit interface]**
"She enters her amount..."
- Type: 10,000 USDC
- Balance shown: 10,245.67 USDC

"...and clicks deposit."
- Click "Deposit" button
- Transaction confirmation
- Loading animation

**[ERC-7540 info box highlights]**
"Notice the ERC-7540 protection - her deposit request is created safely, with a 1-day lock period to prevent any security issues."

**[Transaction confirms]**
- Success notification
- Share tokens received: 10,000 hyUSDC
- Initial allocation shown: GlueX Vault 2 @ 15.2% APY

---

## Scene 5: Automatic Rebalancing (1:45 - 2:20)

**[Screen: Yield Monitoring Dashboard]**

**Narrator:**
"Now the magic happens. Our optimizer bot runs every 5 minutes, checking yields across all whitelisted vaults."

**[Show real-time data]**
- Vault 1: 12.5% APY | TVL: $5.2M | Sharpe: 2.1
- Vault 2: 15.2% APY | TVL: $3.8M | Sharpe: 2.4 ← Current
- Vault 3: 18.7% APY | TVL: $2.1M | Sharpe: 2.0
- Vault 4: 10.8% APY | TVL: $8.5M | Sharpe: 2.3
- Vault 5: 14.3% APY | TVL: $4.6M | Sharpe: 2.6 ← Best!

**[Highlight animation showing calculation]**

"The bot identifies Vault 5 has the best Sharpe ratio - 2.6 - meaning optimal risk-adjusted returns."

**[Show rebalancing notification]**
- Alert: "Better opportunity detected!"
- Improvement: +0.6% APY, +0.2 Sharpe
- Action: Rebalancing...

**[Transaction execution animation]**
1. Withdraw from Vault 2
2. GlueX Router API call
3. Deposit to Vault 5
4. Success!

**[Updated dashboard]**
- New position: Vault 5 @ 14.3% APY
- Sharpe ratio: 2.6
- Time elapsed: 15 seconds

"All done automatically, with optimal gas efficiency."

---

## Scene 6: Results & Benefits (2:20 - 2:45)

**[Screen: Performance Dashboard]**

**Narrator:**
"Fast forward 30 days..."

**[Show performance metrics with animations]**

**Without HyperYield:**
- Manual APY: 12.8% average
- Time spent: 60 hours
- Missed opportunities: 7
- Earnings: $106.67

**With HyperYield:**
- Optimized APY: 14.9% average
- Time spent: 0 hours
- Rebalances executed: 12
- Earnings: $124.17

**[Highlight difference]**
"That's $17.50 more earnings in just one month - a 16.4% improvement - with zero effort."

**[Show cumulative chart]**
"Over time, these optimizations compound significantly."

---

## Scene 7: Security & Trust (2:45 - 2:55)

**[Screen: Security features grid]**

**Narrator:**
"Security is paramount. HyperYield features:"

**[Icons and text appear]**
✓ ERC-7540 Async Vault Standard
✓ Whitelist-only vault access
✓ Multi-signature controls
✓ Emergency pause functionality
✓ Audited smart contracts
✓ Non-custodial architecture

"Your funds, your control, always."

---

## Scene 8: Call to Action (2:55 - 3:00)

**[Screen: Final slide with links]**

**Narrator:**
"Ready to optimize your yields?"

**[Text and links appear]**

🚀 Try HyperYield Today
📖 Read the Docs
💻 GitHub Repository
🎯 Built for Hyperliquid Hackathon

**[QR codes for easy access]**

"HyperYield Optimizer - because your yields should work as hard as you do."

**[Logo animation and fade out]**

---

## Technical Demo Alternative (For Technical Audience)

### Console Output Demonstration

```
$ python optimizer.py

🚀 HyperYield Optimizer started
Check interval: 300s
Min APY difference: 0.5%
Optimization strategy: sharpe
===========================================================

Starting optimization cycle...
Current vault: 0xcdc397...
Current amount: 10000.00 USDC

Scanning vaults for best opportunity...
Vault 0xe25514...: APY=12.50%, Score=2.1000
Vault 0xcdc397...: APY=15.20%, Score=2.4000
Vault 0x8f9291...: APY=18.70%, Score=2.0000
Vault 0x9f75ea...: APY=10.80%, Score=2.3000
Vault 0x63cf7e...: APY=14.30%, Score=2.6000

Best opportunity: 0x63cf7e...
  APY: 14.30%
  Score: 2.6000
  TVL: $4,600,000

Rebalancing recommended: +2.10% APY improvement
Executing rebalance to 0x63cf7e...
Transaction sent: 0xabcd1234...
✅ Rebalancing successful!
📊 Total rebalances: 1

Sleeping for 300s...
```

---

## Demo Preparation Checklist

### Before Recording:

- [ ] Deploy contracts to testnet
- [ ] Fund test wallet with USDC
- [ ] Configure GlueX API credentials
- [ ] Start optimizer bot
- [ ] Prepare frontend with test data
- [ ] Clear browser cache/history
- [ ] Set up screen recording (1080p minimum)
- [ ] Test audio quality
- [ ] Prepare cursor highlighting

### During Recording:

- [ ] Slow, deliberate mouse movements
- [ ] Pause after each action (1-2 seconds)
- [ ] Highlight important elements
- [ ] Use zoom-in for small text
- [ ] Show loading states
- [ ] Capture console output
- [ ] Display transaction confirmations

### After Recording:

- [ ] Add transitions
- [ ] Insert background music (low volume)
- [ ] Add text overlays for clarity
- [ ] Include captions/subtitles
- [ ] Add call-to-action cards
- [ ] Compress to <25MB
- [ ] Export at 60fps
- [ ] Upload to YouTube/Loom

---

## Key Messages to Emphasize

1. **Problem-Solution Fit**: APY volatility is real, automation is the solution
2. **Security First**: ERC-7540, whitelisted vaults, non-custodial
3. **Actual Integration**: Real GlueX API usage, not mocked
4. **Performance**: Concrete numbers showing improvement
5. **Ease of Use**: Set it and forget it
6. **Technical Depth**: For hackathon judges, show architecture

---

## Demo Links to Include

- Live Demo: https://hyperyield-demo.vercel.app
- GitHub: https://github.com/yourusername/hyperliquid-yield-optimizer
- Documentation: https://docs.hyperyield.io
- Contract Address: 0x... (on HyperEVM testnet)
- Loom Video: https://loom.com/share/...

---

## Bonus: Live Q&A Points

**Q: How is this different from other yield optimizers?**
A: Three key differences:
1. ERC-7540 async standard for enhanced security
2. Focus on Sharpe ratio, not just APY
3. Native GlueX integration with 5 whitelisted vaults

**Q: What prevents the bot from being malicious?**
A: Multi-layered security:
1. Bot can only interact with whitelisted vaults
2. Rebalancing cooldown prevents abuse
3. Owner can revoke bot access anytime
4. All actions are on-chain and auditable

**Q: How do gas costs affect returns?**
A: HyperEVM has very low gas costs (~$0.01 per transaction). Rebalancing only occurs when APY improvement exceeds 0.5%, ensuring gas costs are negligible relative to gains.

**Q: Can I withdraw anytime?**
A: Yes! Request redemption, wait for the async period to complete (typically same block on HyperEVM), then claim your assets. ERC-7540 ensures safe processing.
