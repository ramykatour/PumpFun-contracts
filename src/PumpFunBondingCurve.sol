// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

interface IPumpFunToken {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function graduate(address liquidityPool) external;
    function graduated() external view returns (bool);
}

contract PumpFunBondingCurve is Ownable, Initializable {
    
    IERC20 public token;
    address public factory;
    address public feeRecipient;
    
    uint256 public constant GRADUATION_THRESHOLD = 85 * 1e18; // 85 BNB (equivalent to Pump Fun's 85 SOL)
    uint256 public constant FEE_RATE = 100; // 1% fee (100/10000)
    uint256 public constant CREATOR_FEE_RATE = 20; // 0.2% creator fee
    
    uint256 public totalTokensSold;
    uint256 public totalBNBCollected;
    
    struct Step {
        uint256 startSupply;
        uint256 endSupply;
        uint256 startPrice;
        uint256 endPrice;
    }
    
    Step[] public steps;
    
    event TokensPurchased(address indexed buyer, uint256 bnbAmount, uint256 tokenAmount);
    event TokensSold(address indexed seller, uint256 tokenAmount, uint256 bnbAmount);
    event TokenGraduated(address indexed token, address indexed liquidityPool, uint256 totalBNB);
    
    modifier onlyFactory() {
        require(msg.sender == factory, "Only factory can call this");
        _;
    }
    
    constructor() Ownable(msg.sender) {
        // Disable initialization to prevent implementation contract from being used
        _disableInitializers();
    }
    
    function initialize(address _factory, address _feeRecipient) public initializer {
        _transferOwnership(msg.sender);
        factory = _factory;
        feeRecipient = _feeRecipient;
        _initializeSteps();
    }
    
    function _initializeSteps() internal {
        // Step function bonding curve - similar to Pump Fun
        // Each step has a different price progression
        steps.push(Step(0, 1000000 * 1e9, 1 * 1e9, 2 * 1e9)); // 0-1M tokens: 1-2 BNB per billion tokens
        steps.push(Step(1000000 * 1e9, 5000000 * 1e9, 2 * 1e9, 5 * 1e9)); // 1-5M tokens: 2-5 BNB per billion tokens
        steps.push(Step(5000000 * 1e9, 10000000 * 1e9, 5 * 1e9, 10 * 1e9)); // 5-10M tokens: 5-10 BNB per billion tokens
        steps.push(Step(10000000 * 1e9, 50000000 * 1e9, 10 * 1e9, 25 * 1e9)); // 10-50M tokens: 10-25 BNB per billion tokens
        steps.push(Step(50000000 * 1e9, 100000000 * 1e9, 25 * 1e9, 50 * 1e9)); // 50-100M tokens: 25-50 BNB per billion tokens
        steps.push(Step(100000000 * 1e9, 500000000 * 1e9, 50 * 1e9, 100 * 1e9)); // 100-500M tokens: 50-100 BNB per billion tokens
        steps.push(Step(500000000 * 1e9, 1000000000 * 1e9, 100 * 1e9, 200 * 1e9)); // 500M-1B tokens: 100-200 BNB per billion tokens
    }
    
    function setToken(address _token) external onlyFactory {
        require(address(token) == address(0), "Token already set");
        token = IERC20(_token);
    }
    
    function getCurrentPrice() public view returns (uint256) {
        uint256 currentSupply = token.totalSupply();
        
        for (uint256 i = 0; i < steps.length; i++) {
            Step memory step = steps[i];
            if (currentSupply >= step.startSupply && currentSupply < step.endSupply) {
                // Linear interpolation within the step
                uint256 supplyInRange = currentSupply - step.startSupply;
                uint256 rangeSize = step.endSupply - step.startSupply;
                uint256 priceRange = step.endPrice - step.startPrice;
                
                return step.startPrice + (supplyInRange * priceRange / rangeSize);
            }
        }
        
        // If beyond all steps, use the last step's end price
        return steps[steps.length - 1].endPrice;
    }
    
    function getBuyPrice(uint256 tokenAmount) public view returns (uint256) {
        uint256 currentSupply = token.totalSupply();
        uint256 totalCost = 0;
        uint256 remainingAmount = tokenAmount;
        
        for (uint256 i = 0; i < steps.length && remainingAmount > 0; i++) {
            Step memory step = steps[i];
            
            if (currentSupply >= step.endSupply) continue;
            
            uint256 availableInStep = step.endSupply - currentSupply;
            uint256 amountInStep = remainingAmount < availableInStep ? remainingAmount : availableInStep;
            
            // Calculate average price in this step
            uint256 startPrice = getCurrentPriceForSupply(currentSupply);
            uint256 endPrice = getCurrentPriceForSupply(currentSupply + amountInStep);
            uint256 avgPrice = (startPrice + endPrice) / 2;
            
            totalCost = totalCost + (amountInStep * avgPrice / 1e9);
            
            currentSupply = currentSupply + amountInStep;
            remainingAmount = remainingAmount - amountInStep;
        }
        
        return totalCost;
    }
    
    function getSellPrice(uint256 tokenAmount) public view returns (uint256) {
        uint256 currentSupply = token.totalSupply();
        uint256 totalRevenue = 0;
        uint256 remainingAmount = tokenAmount;
        
        // Work backwards through the steps
        for (int256 i = int256(steps.length) - 1; i >= 0 && remainingAmount > 0; i--) {
            Step memory step = steps[uint256(i)];
            
            if (currentSupply <= step.startSupply) continue;
            
            uint256 availableInStep = currentSupply - step.startSupply;
            uint256 amountInStep = remainingAmount < availableInStep ? remainingAmount : availableInStep;
            
            // Calculate average price in this step
            uint256 startPrice = getCurrentPriceForSupply(currentSupply - amountInStep);
            uint256 endPrice = getCurrentPriceForSupply(currentSupply);
            uint256 avgPrice = (startPrice + endPrice) / 2;
            
            totalRevenue = totalRevenue + (amountInStep * avgPrice / 1e9);
            
            currentSupply = currentSupply - amountInStep;
            remainingAmount = remainingAmount - amountInStep;
        }
        
        return totalRevenue;
    }
    
    function getCurrentPriceForSupply(uint256 supply) internal view returns (uint256) {
        for (uint256 i = 0; i < steps.length; i++) {
            Step memory step = steps[i];
            if (supply >= step.startSupply && supply < step.endSupply) {
                uint256 supplyInRange = supply - step.startSupply;
                uint256 rangeSize = step.endSupply - step.startSupply;
                uint256 priceRange = step.endPrice - step.startPrice;
                
                return step.startPrice + (supplyInRange * priceRange / rangeSize);
            }
        }
        
        return steps[steps.length - 1].endPrice;
    }
    
    function buyTokens() external payable {
        _buyTokensInternal();
    }
    
    function sellTokens(uint256 tokenAmount) external {
        require(tokenAmount > 0, "Must sell some tokens");
        require(token.balanceOf(msg.sender) >= tokenAmount, "Insufficient token balance");
        
        uint256 bnbAmount = getSellPrice(tokenAmount);
        require(bnbAmount > 0, "Token amount too small");
        
        uint256 feeAmount = bnbAmount * FEE_RATE / 10000;
        uint256 amountToTransfer = bnbAmount - feeAmount;
        
        // Burn tokens from seller
        IPumpFunToken(address(token)).burn(msg.sender, tokenAmount);
        
        // Transfer BNB to seller
        payable(msg.sender).transfer(amountToTransfer);
        
        // Transfer fee
        payable(feeRecipient).transfer(feeAmount);
        
        totalTokensSold = totalTokensSold - tokenAmount;
        
        emit TokensSold(msg.sender, tokenAmount, amountToTransfer);
    }
    
    function getTokensForBNB(uint256 bnbAmount) public view returns (uint256) {
        uint256 currentSupply = token.totalSupply();
        uint256 tokensToBuy = 0;
        uint256 remainingBNB = bnbAmount;
        
        for (uint256 i = 0; i < steps.length && remainingBNB > 0; i++) {
            Step memory step = steps[i];
            
            if (currentSupply >= step.endSupply) continue;
            
            uint256 availableInStep = step.endSupply - currentSupply;
            uint256 startPrice = getCurrentPriceForSupply(currentSupply);
            
            // Calculate how many tokens we can buy in this step
            uint256 maxTokensInStep = remainingBNB * 1e9 / startPrice;
            uint256 tokensInStep = maxTokensInStep < availableInStep ? maxTokensInStep : availableInStep;
            
            // Calculate actual cost for these tokens
            uint256 actualCost = tokensInStep * (startPrice + getCurrentPriceForSupply(currentSupply + tokensInStep)) / 2e9;
            
            if (actualCost <= remainingBNB) {
                tokensToBuy = tokensToBuy + tokensInStep;
                remainingBNB = remainingBNB - actualCost;
                currentSupply = currentSupply + tokensInStep;
            } else {
                // Calculate exact tokens for remaining BNB
                uint256 exactTokens = remainingBNB * 2e9 / (startPrice + getCurrentPriceForSupply(currentSupply));
                tokensToBuy = tokensToBuy + exactTokens;
                break;
            }
        }
        
        return tokensToBuy;
    }
    
    function _graduateToken() internal {
        // This would be implemented to create a liquidity pool on a DEX
        // For now, we'll just emit an event
        emit TokenGraduated(address(token), address(0), totalBNBCollected);
        
        // Mark token as graduated
        IPumpFunToken(address(token)).graduate(address(0));
    }
    
    function getCurveInfo() external view returns (
        uint256 _totalTokensSold,
        uint256 _totalBNBCollected,
        uint256 _currentPrice,
        uint256 _graduationThreshold,
        bool _graduated
    ) {
        return (
            totalTokensSold,
            totalBNBCollected,
            getCurrentPrice(),
            GRADUATION_THRESHOLD,
            IPumpFunToken(address(token)).graduated()
        );
    }
    
    function getSteps() external view returns (Step[] memory) {
        return steps;
    }
    
    receive() external payable {
        _buyTokensInternal();
    }
    
    function _buyTokensInternal() internal {
        require(msg.value > 0, "Must send BNB");
        
        uint256 feeAmount = msg.value * FEE_RATE / 10000;
        uint256 creatorFeeAmount = msg.value * CREATOR_FEE_RATE / 10000;
        uint256 amountForTokens = msg.value - feeAmount - creatorFeeAmount;
        
        // Transfer fees
        payable(feeRecipient).transfer(feeAmount);
        payable(owner()).transfer(creatorFeeAmount);
        
        // Calculate tokens to buy
        uint256 tokensToBuy = getTokensForBNB(amountForTokens);
        require(tokensToBuy > 0, "Insufficient BNB for minimum tokens");
        
        // Mint tokens to buyer
        IPumpFunToken(address(token)).mint(msg.sender, tokensToBuy);
        
        totalTokensSold = totalTokensSold + tokensToBuy;
        totalBNBCollected = totalBNBCollected + amountForTokens;
        
        emit TokensPurchased(msg.sender, amountForTokens, tokensToBuy);
        
        // Check if token should graduate
        if (totalBNBCollected >= GRADUATION_THRESHOLD) {
            _graduateToken();
        }
    }
}