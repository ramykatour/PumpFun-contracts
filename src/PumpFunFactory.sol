// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./PumpFunToken.sol";
import "./PumpFunBondingCurve.sol";

contract PumpFunFactory is Ownable {
    address public feeRecipient;
    
    struct TokenInfo {
        address tokenAddress;
        address bondingCurveAddress;
        address creator;
        string name;
        string symbol;
        string imageUri;
        string websiteUrl;
        string tokenDescription;
        uint256 createdAt;
        bool active;
    }
    
    mapping(address => TokenInfo) public tokenInfo;
    mapping(address => address[]) public creatorTokens;
    address[] public allTokens;
    
    uint256 public creationFee = 0.01 * 1e18; // 0.01 BNB creation fee
    uint256 public totalTokensCreated;
    
    event TokenCreated(
        address indexed token,
        address indexed bondingCurve,
        address indexed creator,
        string name,
        string symbol,
        string imageUri,
        string websiteUrl,
        string tokenDescription
    );
    
    event CreationFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);
    
    constructor(address _feeRecipient) Ownable(msg.sender) {
        feeRecipient = _feeRecipient;
    }
    
    function createToken(
        string memory name,
        string memory symbol,
        string memory imageUri,
        string memory websiteUrl,
        string memory tokenDescription
    ) external payable {
        require(msg.value >= creationFee, "Insufficient creation fee");
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(symbol).length > 0, "Symbol cannot be empty");
        require(bytes(imageUri).length > 0, "Image URI cannot be empty");
        
        // Transfer creation fee
        payable(feeRecipient).transfer(creationFee);
        
        // Refund excess BNB
        if (msg.value > creationFee) {
            payable(msg.sender).transfer(msg.value - creationFee);
        }
        
        // Deploy new token
        PumpFunToken token = new PumpFunToken(
            name,
            symbol,
            imageUri,
            websiteUrl,
            tokenDescription,
            msg.sender,
            address(0) // Will be set after bonding curve deployment
        );
        
        // Deploy new bonding curve
        PumpFunBondingCurve bondingCurve = new PumpFunBondingCurve();
        bondingCurve.initialize(address(this), feeRecipient);
        bondingCurve.setToken(address(token));
        
        // Update token's bonding curve address
        token.setBondingCurve(address(bondingCurve));
        
        // Store token info
        TokenInfo storage info = tokenInfo[address(token)];
        info.tokenAddress = address(token);
        info.bondingCurveAddress = address(bondingCurve);
        info.creator = msg.sender;
        info.name = name;
        info.symbol = symbol;
        info.imageUri = imageUri;
        info.websiteUrl = websiteUrl;
        info.tokenDescription = tokenDescription;
        info.createdAt = block.timestamp;
        info.active = true;
        
        // Add to creator's tokens
        creatorTokens[msg.sender].push(address(token));
        
        // Add to all tokens
        allTokens.push(address(token));
        
        totalTokensCreated++;
        
        emit TokenCreated(
            address(token),
            address(bondingCurve),
            msg.sender,
            name,
            symbol,
            imageUri,
            websiteUrl,
            tokenDescription
        );
    }
    
    function getTokenInfo(address tokenAddress) external view returns (TokenInfo memory) {
        return tokenInfo[tokenAddress];
    }
    
    function getCreatorTokens(address creator) external view returns (address[] memory) {
        return creatorTokens[creator];
    }
    
    function getAllTokens() external view returns (address[] memory) {
        return allTokens;
    }
    
    function getActiveTokens(uint256 offset, uint256 limit) external view returns (address[] memory) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < allTokens.length; i++) {
            if (tokenInfo[allTokens[i]].active) {
                activeCount++;
            }
        }
        
        uint256 resultLength = limit > activeCount - offset ? activeCount - offset : limit;
        address[] memory result = new address[](resultLength);
        
        uint256 resultIndex = 0;
        for (uint256 i = 0; i < allTokens.length && resultIndex < resultLength; i++) {
            if (tokenInfo[allTokens[i]].active) {
                if (offset > 0) {
                    offset--;
                } else {
                    result[resultIndex] = allTokens[i];
                    resultIndex++;
                }
            }
        }
        
        return result;
    }
    
    function getTopTokensByVolume(uint256 limit) external view returns (address[] memory) {
        // This would require volume tracking - simplified version returns recent tokens
        uint256 resultLength = limit > allTokens.length ? allTokens.length : limit;
        address[] memory result = new address[](resultLength);
        
        uint256 startIndex = allTokens.length > resultLength ? allTokens.length - resultLength : 0;
        for (uint256 i = 0; i < resultLength; i++) {
            result[i] = allTokens[startIndex + i];
        }
        
        return result;
    }
    
    function setCreationFee(uint256 newFee) external onlyOwner {
        uint256 oldFee = creationFee;
        creationFee = newFee;
        emit CreationFeeUpdated(oldFee, newFee);
    }
    
    function setFeeRecipient(address newRecipient) external onlyOwner {
        address oldRecipient = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(oldRecipient, newRecipient);
    }
    
    function deactivateToken(address tokenAddress) external onlyOwner {
        require(tokenInfo[tokenAddress].active, "Token already inactive");
        tokenInfo[tokenAddress].active = false;
    }
    
    function getTokenCount() external view returns (uint256) {
        return allTokens.length;
    }
    
    function getActiveTokenCount() external view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < allTokens.length; i++) {
            if (tokenInfo[allTokens[i]].active) {
                count++;
            }
        }
        return count;
    }
}