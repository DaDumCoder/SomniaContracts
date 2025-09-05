// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.5/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.5/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.5/contracts/security/ReentrancyGuard.sol";

contract HOLE is ERC20, Ownable, ReentrancyGuard {
    uint256 public pricePerTokenWei;
    uint256 public immutable maxSupply;
    bool public mintOpen = true;
    bool public transfersEnabled = false;

    event Minted(address indexed minter, uint256 amount, uint256 paid);
    event PriceChanged(uint256 oldPrice, uint256 newPrice);
    event MintOpenChanged(bool open);
    event TransfersEnabledChanged(bool enabled);

    constructor(
        uint256 _pricePerTokenWei,
        uint256 _maxSupplyWholeTokens,
        address _initialOwner
    ) ERC20("HOLE", "HOLE") {
        require(_maxSupplyWholeTokens > 0, "cap=0");
        require(_initialOwner != address(0), "owner=0");
        pricePerTokenWei = _pricePerTokenWei;
        maxSupply = _maxSupplyWholeTokens * (10 ** uint256(decimals()));
        _transferOwnership(_initialOwner);
    }

    function mint(uint256 amount) external payable nonReentrant {
        require(mintOpen, "mint paused");
        require(amount > 0, "amount=0");
        uint256 cost = pricePerTokenWei * amount;
        require(msg.value == cost, "incorrect ETH");
        uint256 units = amount * (10 ** uint256(decimals()));
        require(totalSupply() + units <= maxSupply, "cap exceeded");
        _mint(msg.sender, units);
        emit Minted(msg.sender, amount, msg.value);
    }

    function setPrice(uint256 newPriceWei) external onlyOwner {
        uint256 old = pricePerTokenWei;
        pricePerTokenWei = newPriceWei;
        emit PriceChanged(old, newPriceWei);
    }

    function setMintOpen(bool open) external onlyOwner {
        mintOpen = open;
        emit MintOpenChanged(open);
    }

    function setTransfersEnabled(bool enabled) external onlyOwner {
        transfersEnabled = enabled;
        emit TransfersEnabledChanged(enabled);
    }

    function withdraw(address payable to) external onlyOwner nonReentrant {
        require(to != address(0), "to=0");
        to.transfer(address(this).balance);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        if (from != address(0) && to != address(0)) {
            require(transfersEnabled, "transfers disabled");
        }
    }

    function tokensLeft() external view returns (uint256) {
        return (maxSupply - totalSupply()) / (10 ** uint256(decimals()));
    }

    receive() external payable { revert("Use mint()"); }
    fallback() external payable { revert("Use mint()"); }
}