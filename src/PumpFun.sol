// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./PumpFunFactory.sol";
import "./PumpFunToken.sol";
import "./PumpFunBondingCurve.sol";

contract PumpFun is Ownable {
    PumpFunFactory public factory;
    
    struct TokenSummary {
        address tokenAddress;
        address bondingCurveAddress;
        address creator;
        string name;
        string symbol;
        string imageUri;
        string websiteUrl;
        string tokenDescription;
        uint256 totalSupply;
        uint256 currentPrice;
        uint256 totalBNBCollected;
        uint256 graduationThreshold;
        bool graduated;
        uint256 createdAt;
        bool active;
    }
    
    event TokenCreatedViaPumpFun(
        address indexed token,
        address indexed bondingCurve,
        address indexed creator,
        string name,
        string symbol
    );
    
    constructor(address _factory) Ownable(msg.sender) {
        factory = PumpFunFactory(_factory);
    }
    
    function getTokenSummary(address tokenAddress) public view returns (TokenSummary memory) {
        PumpFunFactory.TokenInfo memory info = factory.getTokenInfo(tokenAddress);
        require(info.tokenAddress != address(0), "Token does not exist");
        
        PumpFunToken token = PumpFunToken(tokenAddress);
        PumpFunBondingCurve bondingCurve = PumpFunBondingCurve(payable(info.bondingCurveAddress));
        
        (
            ,
            uint256 totalBNBCollected,
            uint256 currentPrice,
            uint256 graduationThreshold,
            bool graduated
        ) = bondingCurve.getCurveInfo();
        
        return TokenSummary({
            tokenAddress: tokenAddress,
            bondingCurveAddress: info.bondingCurveAddress,
            creator: info.creator,
            name: info.name,
            symbol: info.symbol,
            imageUri: info.imageUri,
            websiteUrl: info.websiteUrl,
            tokenDescription: info.tokenDescription,
            totalSupply: token.totalSupply(),
            currentPrice: currentPrice,
            totalBNBCollected: totalBNBCollected,
            graduationThreshold: graduationThreshold,
            graduated: graduated,
            createdAt: info.createdAt,
            active: info.active
        });
    }
    
    function createToken(
        string memory name,
        string memory symbol,
        string memory imageUri,
        string memory websiteUrl,
        string memory tokenDescription
    ) external payable {
        // Forward the creation call to the factory
        factory.createToken{value: msg.value}(
            name,
            symbol,
            imageUri,
            websiteUrl,
            tokenDescription
        );
        
        // Get the created token address (it will be the last token created by this user)
        address[] memory creatorTokens = factory.getCreatorTokens(msg.sender);
        address tokenAddress = creatorTokens[creatorTokens.length - 1];
        
        // Get token info to get bonding curve address
        PumpFunFactory.TokenInfo memory info = factory.getTokenInfo(tokenAddress);
        
        emit TokenCreatedViaPumpFun(
            tokenAddress,
            info.bondingCurveAddress,
            msg.sender,
            name,
            symbol
        );
    }
    
    function buyTokens(address tokenAddress) external payable {
        PumpFunFactory.TokenInfo memory info = factory.getTokenInfo(tokenAddress);
        require(info.active, "Token is not active");
        require(!PumpFunToken(tokenAddress).graduated(), "Token has graduated");
        
        PumpFunBondingCurve bondingCurve = PumpFunBondingCurve(payable(info.bondingCurveAddress));
        
        // Forward BNB to bonding curve
        (bool success, ) = address(bondingCurve).call{value: msg.value}("");
        require(success, "BNB transfer failed");
    }
    
    function sellTokens(address tokenAddress, uint256 tokenAmount) external {
        PumpFunFactory.TokenInfo memory info = factory.getTokenInfo(tokenAddress);
        require(info.active, "Token is not active");
        require(!PumpFunToken(tokenAddress).graduated(), "Token has graduated");
        
        PumpFunToken token = PumpFunToken(tokenAddress);
        PumpFunBondingCurve bondingCurve = PumpFunBondingCurve(payable(info.bondingCurveAddress));
        
        // Approve bonding curve to spend tokens
        token.approve(address(bondingCurve), tokenAmount);
        
        // Sell tokens
        bondingCurve.sellTokens(tokenAmount);
    }
    
    function getBuyPrice(address tokenAddress, uint256 tokenAmount) external view returns (uint256) {
        PumpFunFactory.TokenInfo memory info = factory.getTokenInfo(tokenAddress);
        require(info.tokenAddress != address(0), "Token does not exist");
        
        PumpFunBondingCurve bondingCurve = PumpFunBondingCurve(payable(info.bondingCurveAddress));
        return bondingCurve.getBuyPrice(tokenAmount);
    }
    
    function getSellPrice(address tokenAddress, uint256 tokenAmount) external view returns (uint256) {
        PumpFunFactory.TokenInfo memory info = factory.getTokenInfo(tokenAddress);
        require(info.tokenAddress != address(0), "Token does not exist");
        
        PumpFunBondingCurve bondingCurve = PumpFunBondingCurve(payable(info.bondingCurveAddress));
        return bondingCurve.getSellPrice(tokenAmount);
    }
    
    function getTokensForBNB(address tokenAddress, uint256 bnbAmount) external view returns (uint256) {
        PumpFunFactory.TokenInfo memory info = factory.getTokenInfo(tokenAddress);
        require(info.tokenAddress != address(0), "Token does not exist");
        
        PumpFunBondingCurve bondingCurve = PumpFunBondingCurve(payable(info.bondingCurveAddress));
        return bondingCurve.getTokensForBNB(bnbAmount);
    }
    
    function getRecentTokens(uint256 limit) external view returns (TokenSummary[] memory) {
        address[] memory tokenAddresses = factory.getTopTokensByVolume(limit);
        TokenSummary[] memory summaries = new TokenSummary[](tokenAddresses.length);
        
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            summaries[i] = getTokenSummary(tokenAddresses[i]);
        }
        
        return summaries;
    }
    
    function getActiveTokens(uint256 offset, uint256 limit) external view returns (TokenSummary[] memory) {
        address[] memory tokenAddresses = factory.getActiveTokens(offset, limit);
        TokenSummary[] memory summaries = new TokenSummary[](tokenAddresses.length);
        
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            summaries[i] = getTokenSummary(tokenAddresses[i]);
        }
        
        return summaries;
    }
    
    function getCreatorTokens(address creator) external view returns (TokenSummary[] memory) {
        address[] memory tokenAddresses = factory.getCreatorTokens(creator);
        TokenSummary[] memory summaries = new TokenSummary[](tokenAddresses.length);
        
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            summaries[i] = getTokenSummary(tokenAddresses[i]);
        }
        
        return summaries;
    }
    
    function getUserTokenBalance(address user, address tokenAddress) external view returns (uint256) {
        return PumpFunToken(tokenAddress).balanceOf(user);
    }
    
    function getCreationFee() external view returns (uint256) {
        return factory.creationFee();
    }
    
    function getTotalTokensCreated() external view returns (uint256) {
        return factory.totalTokensCreated();
    }
    
    function getFactory() external view returns (address) {
        return address(factory);
    }
    
    // Emergency functions
    function updateFactory(address newFactory) external onlyOwner {
        factory = PumpFunFactory(newFactory);
    }
    
    // Fallback to receive BNB
    receive() external payable {}
}