// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
 * HOLE — ERC20 with paid/free mint, global transferability toggle,
 * and per-wallet mint cap (in whole tokens).
 *
 * - pricePerTokenWei: 0 => free, else exact ETH must be sent.
 * - walletMintCap: maximum WHOLE tokens a wallet can mint via mint().
 *   0 => no per-wallet limit.
 * - mintedWhole[addr]: WHOLE tokens minted so far by that wallet.
 * - transfersEnabled: when false, wallet-to-wallet transfers are blocked
 *   (mint/burn still allowed).
 *
 * OpenZeppelin v4.9.x
 */

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract HOLE is ERC20, Ownable, ReentrancyGuard {
    /// @notice Price per ONE whole token (18 decimals) in wei. 0 => free mint.
    uint256 public pricePerTokenWei;

    /// @notice Hard cap in smallest units (includes decimals)
    uint256 public immutable maxSupply;

    /// @notice Global mint switch
    bool public mintOpen = true;

    /// @notice Global transfers toggle: false => non-transferable
    bool public transfersEnabled = false;

    /// @notice Per-wallet mint cap in WHOLE tokens (0 => no cap)
    uint256 public walletMintCap;

    /// @notice WHOLE tokens minted via mint() per wallet
    mapping(address => uint256) public mintedWhole;

    event Minted(address indexed minter, uint256 amount, uint256 paid);
    event PriceChanged(uint256 oldPrice, uint256 newPrice);
    event MintOpenChanged(bool open);
    event TransfersEnabledChanged(bool enabled);
    event WalletMintCapChanged(uint256 oldCap, uint256 newCap);

    constructor(
        uint256 _pricePerTokenWei,        // e.g., 0 (free) or 0.001 ether
        uint256 _maxSupplyWholeTokens,    // e.g., 1_000_000
        address _initialOwner,
        uint256 _walletMintCapWhole       // e.g., 0 (no cap) or 1000
    ) ERC20("HOLE", "HOLE") {
        require(_maxSupplyWholeTokens > 0, "cap=0");
        require(_initialOwner != address(0), "owner=0");

        pricePerTokenWei = _pricePerTokenWei; // can be 0
        maxSupply = _maxSupplyWholeTokens * (10 ** uint256(decimals()));
        walletMintCap = _walletMintCapWhole;  // 0 => unlimited
        _transferOwnership(_initialOwner);
    }

    /// @notice Mint `amount` WHOLE tokens by paying exact ETH (0 if free)
    function mint(uint256 amount) external payable nonReentrant {
        require(mintOpen, "mint paused");
        require(amount > 0, "amount=0");

        // Per-wallet limit (in whole tokens)
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

    /// @notice Set new price in wei (0 allowed for free mint)
    function setPrice(uint256 newPriceWei) external onlyOwner {
        uint256 old = pricePerTokenWei;
        pricePerTokenWei = newPriceWei;
        emit PriceChanged(old, newPriceWei);
    }

    function setMintOpen(bool open) external onlyOwner {
        mintOpen = open;
        emit MintOpenChanged(open);
    }

    /// @notice Enable/disable all transfers (does not affect minting)
    function setTransfersEnabled(bool enabled) external onlyOwner {
        transfersEnabled = enabled;
        emit TransfersEnabledChanged(enabled);
    }

    /// @notice Set per-wallet mint cap (WHOLE tokens). 0 => no cap.
    function setWalletMintCap(uint256 newCapWhole) external onlyOwner {
        uint256 old = walletMintCap;
        walletMintCap = newCapWhole;
        emit WalletMintCapChanged(old, newCapWhole);
    }

    function withdraw(address payable to) external onlyOwner nonReentrant {
        require(to != address(0), "to=0");
        to.transfer(address(this).balance);
    }

    // ---------- Transfer gate (blocks transfer/transferFrom when disabled) ----------
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 /* amount */
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, 0);
        // Allow mint (from==0) and burn (to==0); block regular transfers when disabled.
        if (from != address(0) && to != address(0)) {
            require(transfersEnabled, "transfers disabled");
        }
    }

    // ---------- Views ----------
    function tokensLeft() external view returns (uint256) {
        return (maxSupply - totalSupply()) / (10 ** uint256(decimals()));
    }

    // ---------- Safety ----------
    receive() external payable { revert("Use mint()"); }
    fallback() external payable { revert("Use mint()"); }
}