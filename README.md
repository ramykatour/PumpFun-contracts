# Pump Fun EVM Clone

A complete EVM implementation of Pump Fun's functionality, deployed on BSC Testnet. This allows users to create tokens with metadata (image URL, website link, description) and trade them using a bonding curve mechanism.

## 🚀 **Quick Start**

### **1. Setup Environment**
```bash
cd contracts
npm install
cp .env.example .env
```

### **2. Configure Environment**
Edit `.env` file with your credentials:
```env
BSC_TESTNET_URL=https://data-seed-prebsc-1-s1.binance.org:8545
PRIVATE_KEY=your_private_key_here
BSCSCAN_API_KEY=your_bscscan_api_key_here
```

### **3. Compile Contracts**
```bash
npm run compile
```

### **4. Deploy to BSC Testnet**
```bash
npm run deploy:bsctestnet
```

### **5. Verify Contracts**
```bash
npm run verify:bsctestnet
```

## ✅ **Testing**

### **Run All Tests**
```bash
npm test
```

### **Run Configuration Test**
```bash
npx hardhat test test/deployment.test.js
```

### **Clean Build**
```bash
npm run clean
npm run compile
```

## 📋 **Features**

### **Core Functionality**
- ✅ **Token Creation**: Create meme tokens with custom metadata (name, symbol, image URL, website link, description)
- ✅ **Bonding Curve**: Step function bonding curve similar to Pump Fun for fair token pricing
- ✅ **Trading**: Buy and sell tokens directly through the bonding curve
- ✅ **Graduation**: Tokens automatically graduate when they reach the market cap threshold
- ✅ **Fee Mechanism**: 1% trading fee with 0.2% going to token creators

### **Smart Contracts**

#### 1. **PumpFunToken.sol** - ERC20 Token with Metadata
- Standard ERC20 token with additional metadata support
- Functions for minting/burning (only callable by bonding curve)
- Metadata update capabilities for token creators
- Graduation mechanism when token reaches threshold

#### 2. **PumpFunBondingCurve.sol** - Step Function Bonding Curve
- **7-step bonding curve** similar to Pump Fun:
  - 0-1M tokens: 1-2 BNB per billion tokens
  - 1-5M tokens: 2-5 BNB per billion tokens
  - 5-10M tokens: 5-10 BNB per billion tokens
  - 10-50M tokens: 10-25 BNB per billion tokens
  - 50-100M tokens: 25-50 BNB per billion tokens
  - 100-500M tokens: 50-100 BNB per billion tokens
  - 500M-1B tokens: 100-200 BNB per billion tokens
- **Buy/Sell functionality** with proper price calculations
- **Fee mechanism**: 1% trading fee (0.8% protocol, 0.2% creator)
- **Automatic graduation** at 85 BNB threshold
- **Real-time price calculations** based on supply

#### 3. **PumpFunFactory.sol** - Token Deployment Factory
- Deploys new token and bonding curve pairs
- **Creation fee**: 0.01 BNB per token
- Tracks token information and creator relationships
- Manages token activation/deactivation
- Provides token discovery functions

#### 4. **PumpFun.sol** - Main User Interface
- **Single entry point** for all user interactions
- Coordinates between factory and bonding curves
- **Comprehensive token information** retrieval
- **Trading functions** with proper error handling
- **Token discovery** and statistics

## 🎯 **Bonding Curve Details**

### **Step Function Pricing**
The bonding curve uses a step function with 7 steps, each with different price progression to ensure fair launch and price discovery.

### **Graduation Mechanism**
- Tokens graduate when 85 BNB is collected in the bonding curve
- Upon graduation, tokens are marked as graduated and can be listed on DEXes
- Progress is tracked and displayed in real-time

### **Fee Structure**
- **Creation Fee**: 0.01 BNB to create a new token
- **Trading Fee**: 1% on all buys and sells
  - 0.8% goes to protocol
  - 0.2% goes to token creator

## 📊 **Deployment Information**

After deployment, contract addresses are saved in `deployment-bsctestnet.json`:

```json
{
  "network": "bsctestnet",
  "pumpFunFactory": "0x...",
  "pumpFunMain": "0x...",
  "feeRecipient": "0x...",
  "deployer": "0x...",
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

### **Contract Addresses**
- **PumpFun Main**: Primary contract for user interactions
- **PumpFun Factory**: Factory contract for token deployment
- **Fee Recipient**: Address receiving creation and trading fees

## 🔧 **Usage Examples**

### **Creating a Token**

```javascript
const pumpFunAddress = "0x..."; // Your deployed PumpFun contract address
const pumpFun = await ethers.getContractAt("PumpFun", pumpFunAddress);

// Create a new token
await pumpFun.createToken(
  "My Meme Token",
  "MEME",
  "https://example.com/token-image.png",
  "https://mytoken.com",
  "The best meme token ever!",
  { value: ethers.utils.parseEther("0.01") }
);
```

### **Buying Tokens**

```javascript
const tokenAddress = "0x..."; // Address of the token you want to buy
const bnbAmount = ethers.utils.parseEther("0.1"); // 0.1 BNB

await pumpFun.buyTokens(tokenAddress, { value: bnbAmount });
```

### **Selling Tokens**

```javascript
const tokenAddress = "0x...";
const tokenAmount = ethers.utils.parseEther("1000"); // 1000 tokens

await pumpFun.sellTokens(tokenAddress, tokenAmount);
```

### **Getting Token Information**

```javascript
const tokenAddress = "0x...";
const summary = await pumpFun.getTokenSummary(tokenAddress);

console.log("Token Name:", summary.name);
console.log("Token Symbol:", summary.symbol);
console.log("Current Price:", summary.currentPrice);
console.log("Total Supply:", summary.totalSupply);
console.log("BNB Collected:", summary.totalBNBCollected);
console.log("Graduated:", summary.graduated);
```

### **Getting Price Information**

```javascript
const tokenAddress = "0x...";
const bnbAmount = ethers.utils.parseEther("0.1");

// Get how many tokens you can buy with 0.1 BNB
const tokensToBuy = await pumpFun.getTokensForBNB(tokenAddress, bnbAmount);

// Get cost to buy specific amount of tokens
const buyPrice = await pumpFun.getBuyPrice(tokenAddress, tokensToBuy);

// Get revenue from selling specific amount of tokens
const sellPrice = await pumpFun.getSellPrice(tokenAddress, tokensToBuy.div(2));
```

## 🌐 **Frontend Integration**

The contracts are designed to be easily integrated with frontend applications:

### **Key Functions for Frontend**

1. **Token Creation**: `createToken(name, symbol, imageUri, websiteUrl, tokenDescription)`
2. **Buying**: `buyTokens(tokenAddress, { value: bnbAmount })`
3. **Selling**: `sellTokens(tokenAddress, tokenAmount)`
4. **Token Info**: `getTokenSummary(tokenAddress)`
5. **Price Info**: `getBuyPrice()`, `getSellPrice()`, `getTokensForBNB()`
6. **Token Lists**: `getRecentTokens()`, `getActiveTokens()`, `getCreatorTokens()`

### **Events to Listen For**

- `TokenCreatedViaPumpFun`: When new tokens are created
- `TokensPurchased`: When tokens are bought
- `TokensSold`: When tokens are sold
- `TokenGraduated`: When tokens graduate to DEX

## 🔐 **Security Considerations**

1. **Initialization**: All contracts use proper initialization patterns
2. **Access Control**: Only authorized addresses can call sensitive functions
3. **Reentrancy Protection**: Standard reentrancy guards are used
4. **Overflow Protection**: SafeMath is used for all arithmetic operations
5. **Fee Distribution**: Fees are securely transferred to recipients

## 🛠️ **Development**

### **Project Structure**
```
contracts/
├── src/
│   ├── PumpFunToken.sol          # ERC20 token with metadata
│   ├── PumpFunBondingCurve.sol   # Bonding curve implementation
│   ├── PumpFunFactory.sol        # Token deployment factory
│   └── PumpFun.sol              # Main user interface
├── scripts/
│   ├── deploy.js                # Deployment script
│   └── verify.js                # Verification script
│
├── hardhat.config.js            # Hardhat configuration
├── package.json                 # Dependencies and scripts
└── README.md                    # This file
```

### **Scripts Available**
```bash
npm run compile          # Compile contracts
npm run deploy:bsctestnet  # Deploy to BSC Testnet
npm run verify:bsctestnet  # Verify contracts on BscScan
npm run clean            # Clean build artifacts
```

## 📝 **Troubleshooting**

### **Common Issues**

1. **Compilation Errors**
   ```bash
   npm run clean
   npm run compile
   ```

2. **Deployment Fails**
   - Check BSC Testnet RPC URL in `.env`
   - Ensure account has sufficient BNB balance
   - Verify private key is correct

3. **Verification Fails**
   - Ensure BSCSCAN_API_KEY is valid
   - Wait for a few blocks after deployment
   - Check constructor arguments match deployment

4. **Test Failures**
   ```bash
   npm run clean
   npm run compile
   npm test
   ```

### **Network Configuration**

**BSC Testnet**
- RPC URL: `https://data-seed-prebsc-1-s1.binance.org:8545`
- Chain ID: 97
- Currency: BNB
- Explorer: `https://testnet.bscscan.com`

## 🎯 **Future Enhancements**

1. **DEX Integration**: Automatic liquidity pool creation on graduation
2. **Volume Tracking**: Track trading volume for trending tokens
3. **Advanced Metadata**: Support for more token metadata
4. **Multi-chain Support**: Deploy on other EVM chains
5. **Enhanced UI/UX**: More sophisticated frontend interfaces

## 📄 **License**

MIT License - see LICENSE file for details

## 🤝 **Support**

For support and questions:
1. Check the troubleshooting section
2. Review the test files for usage examples
3. Ensure you're using the correct network configuration
4. Verify contract addresses after deployment

---

**Happy token creation! 🚀**