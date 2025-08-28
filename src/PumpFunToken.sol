// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract PumpFunToken is ERC20, Ownable {
    using Strings for uint256;
    
    string public imageUri;
    string public websiteUrl;
    string public tokenDescription;
    address public bondingCurve;
    bool public graduated;
    
    event TokenGraduated(address indexed token, address indexed liquidityPool);
    event MetadataUpdated(string imageUri, string websiteUrl, string tokenDescription);
    
    modifier onlyBondingCurve() {
        require(msg.sender == bondingCurve, "Only bonding curve can call this");
        _;
    }
    
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _imageUri,
        string memory _websiteUrl,
        string memory _tokenDescription,
        address _creator,
        address _bondingCurve
    ) ERC20(_name, _symbol) Ownable(_creator) {
        imageUri = _imageUri;
        websiteUrl = _websiteUrl;
        tokenDescription = _tokenDescription;
        bondingCurve = _bondingCurve;
        
        // Mint initial supply to creator
        _mint(_creator, 810000000000 * 10**decimals()); // 810 billion tokens (mimicking Pump Fun)
    }
    
    function mint(address to, uint256 amount) external onlyBondingCurve {
        _mint(to, amount);
    }
    
    function burn(address from, uint256 amount) external onlyBondingCurve {
        _burn(from, amount);
    }
    
    function setBondingCurve(address _bondingCurve) external onlyOwner {
        bondingCurve = _bondingCurve;
    }
    
    function updateMetadata(
        string memory _imageUri,
        string memory _websiteUrl,
        string memory _tokenDescription
    ) external onlyOwner {
        imageUri = _imageUri;
        websiteUrl = _websiteUrl;
        tokenDescription = _tokenDescription;
        emit MetadataUpdated(_imageUri, _websiteUrl, _tokenDescription);
    }
    
    function graduate(address liquidityPool) external onlyBondingCurve {
        require(!graduated, "Token already graduated");
        graduated = true;
        bondingCurve = address(0);
        emit TokenGraduated(address(this), liquidityPool);
    }
    
    function getTokenInfo() external view returns (
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        string memory _imageUri,
        string memory _websiteUrl,
        string memory _tokenDescription,
        bool _graduated,
        address _bondingCurve
    ) {
        return (
            super.name(),
            super.symbol(),
            super.totalSupply(),
            imageUri,
            websiteUrl,
            tokenDescription,
            graduated,
            bondingCurve
        );
    }
}