// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
 * SLAP — ERC20 with paid/free mint, global transferability toggle,
 * and per-wallet mint cap (in whole tokens).
 * Difference from v1: name/symbol configurable via constructor.
 */

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SLAP is ERC20, Ownable, ReentrancyGuard {
    uint256 public pricePerTokenWei;     // price per ONE whole token (18 decimals) in wei; 0 => free
    uint256 public immutable maxSupply;  // hard cap in smallest units
    bool public mintOpen = true;         // global mint switch
    bool public transfersEnabled = false;// global transfers toggle (false => non-transferable)
    uint256 public walletMintCap;        // per-wallet cap in WHOLE tokens (0 => no cap)
    mapping(address => uint256) public mintedWhole; // WHOLE tokens minted per wallet via mint()

    event Minted(address indexed minter, uint256 amount, uint256 paid);
    event PriceChanged(uint256 oldPrice, uint256 newPrice);
    event MintOpenChanged(bool open);
    event TransfersEnabledChanged(bool enabled);
    event WalletMintCapChanged(uint256 oldCap, uint256 newCap);

    /**
     * @param _name   token name
     * @param _symbol token symbol
     * @param _pricePerTokenWei  0 (free) or e.g., 0.001 ether
     * @param _maxSupplyWholeTokens cap in WHOLE tokens (e.g., 1_000_000)
     * @param _initialOwner owner address
     * @param _walletMintCapWhole per-wallet cap in WHOLE tokens (0 => no cap)
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _pricePerTokenWei,
        uint256 _maxSupplyWholeTokens,
        address _initialOwner,
        uint256 _walletMintCapWhole
    ) ERC20(_name, _symbol) Ownable(_initialOwner) {
        require(_maxSupplyWholeTokens > 0, "cap=0");
        require(_initialOwner != address(0), "owner=0");

        pricePerTokenWei = _pricePerTokenWei; // can be 0
        maxSupply = _maxSupplyWholeTokens * (10 ** uint256(decimals()));
        walletMintCap = _walletMintCapWhole;  // 0 => unlimited

        // Using OZ 4.9.x Ownable(): default owner msg.sender; move to desired owner:
        //_transferOwnership(_initialOwner);
    }

    /// @notice Mint `amount` WHOLE tokens by paying exact ETH (0 if free)
    function mint(uint256 amount) external payable nonReentrant {
        require(mintOpen, "mint paused");
        require(amount > 0, "amount=0");

        if (walletMintCap > 0) {
            require(mintedWhole[msg.sender] + amount <= walletMintCap, "wallet cap exceeded");
        }

        uint256 cost = pricePerTokenWei * amount;
        require(msg.value == cost, "incorrect ETH");

        uint256 units = amount * (10 ** uint256(decimals()));
        require(totalSupply() + units <= maxSupply, "cap exceeded");

        mintedWhole[msg.sender] += amount;
        _mint(msg.sender, units);
        emit Minted(msg.sender, amount, msg.value);
    }

    // ---------- Admin ----------
    function setPrice(uint256 newPriceWei) external onlyOwner {
        uint256 old = pricePerTokenWei;
        pricePerTokenWei = newPriceWei;
        emit PriceChanged(old, newPriceWei);
    }

    function setMintOpen(bool open) external onlyOwner {
        mintOpen = open;
        emit MintOpenChanged(open);
    }

    /// Enable/disable all transfers (does not affect minting)
    function setTransfersEnabled(bool enabled) external onlyOwner {
        transfersEnabled = enabled;
        emit TransfersEnabledChanged(enabled);
    }

    /// Set per-wallet mint cap (WHOLE tokens). 0 => no cap.
    function setWalletMintCap(uint256 newCapWhole) external onlyOwner {
        uint256 old = walletMintCap;
        walletMintCap = newCapWhole;
        emit WalletMintCapChanged(old, newCapWhole);
    }

    function withdraw(address payable to) external onlyOwner nonReentrant {
        require(to != address(0), "to=0");
        to.transfer(address(this).balance);
    }

    // ---------- Transfer gate ----------
    function _update(
    address from,
    address to,
    uint256 value
    ) 
    
    internal virtual override {
    // Block wallet-to-wallet transfers if disabled (mint/burn allowed)
    if (from != address(0) && to != address(0)) {
        require(transfersEnabled, "transfers disabled");
         }
    super._update(from, to, value);
    }


    // ---------- Views ----------
    function tokensLeft() external view returns (uint256) {
        return (maxSupply - totalSupply()) / (10 ** uint256(decimals()));
    }

    // ---------- Safety ----------
    receive() external payable { revert("Use mint()"); }
    fallback() external payable { revert("Use mint()"); }
}