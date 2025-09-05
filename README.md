# SomniaContracts
---

# SomniaContracts

Mintable **ERC-20** token contracts for the Somnia network (and any EVM chain).
Current primary contract: **`SLAP`** — a configurable ERC-20 with:

* free **or** paid minting (price per whole token, in wei)
* global **mint pause/unpause**
* global **transferability toggle** (non-transferable until enabled)
* **per-wallet mint cap** (in whole tokens)
* fixed **max supply** (cap enforced)
* **withdraw** function for owner
* simple `tokensLeft()` helper

Built with **OpenZeppelin v5** + **thirdweb CLI**.

---

## Table of contents

* [Prerequisites](#prerequisites)
* [Quick start](#quick-start)
* [Build](#build)
* [Deploy (thirdweb)](#deploy-thirdweb)
* [Optional: Publish to thirdweb registry](#optional-publish-to-thirdweb-registry)
* [Contract: SLAP](#contract-slap)

  * [Constructor](#constructor)
  * [Admin functions](#admin-functions)
  * [Read functions](#read-functions)
  * [Transfer gating](#transfer-gating)
* [Troubleshooting](#troubleshooting)
* [Notes](#notes)
* [License](#license)

---

## Prerequisites

* **Node.js 18+** and **npm**
* A wallet (MetaMask) with gas on your target chain (e.g., Somnia)
* (Codespaces/headless only) a **thirdweb secret key** if the CLI asks for “device link”

  * Get one at: [https://thirdweb.com/dashboard/settings/api-keys](https://thirdweb.com/dashboard/settings/api-keys)

---

## Quick start

```bash
# clone & switch to the working branch
git clone https://github.com/DaDumCoder/SomniaContracts.git
cd SomniaContracts
git checkout feature/flexCA

# install deps
npm install

# (already in package.json) OpenZeppelin v5 is used
# you should see @openzeppelin/contracts@5.x
npm ls @openzeppelin/contracts
```

> Contracts live in `contracts/`. Only keep the file you want to compile/deploy there (e.g., `SLAP.sol`).

---

## Build

Build the contracts with thirdweb:

```bash
npx thirdweb build
# If prompted: “compile with solc?” -> Y
```

You should see a success message with suggested extensions.

---

## Deploy (thirdweb)

From the repo root:

```bash
# If you’re in Codespaces or the CLI shows a “device link” warning, set your secret:
export THIRDWEB_SECRET_KEY="sk_live_...your_key..."

# then deploy
npx thirdweb@latest deploy -k "$THIRDWEB_SECRET_KEY"
```

This opens the thirdweb deploy UI:

1. Select **`SLAP`**.
2. Choose your **network** (Somnia, testnet, or any EVM chain).
3. Fill constructor params (see below) and click **Deploy Now**.
4. Confirm the transaction in your wallet.

After deploy, you’ll get the **contract address**. Save it for your game/UI.

---

## Optional: Publish to thirdweb registry

Publishing makes the contract discoverable/typed in the thirdweb SDK UIs.

```bash
export THIRDWEB_SECRET_KEY="sk_live_...your_key..."
npx thirdweb publish -k "$THIRDWEB_SECRET_KEY"
```

Follow the prompts (name, version, icon, description).

---

## Contract: `SLAP`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SLAP is ERC20, Ownable, ReentrancyGuard {
    // ...
}
```

### Constructor

```solidity
constructor(
  string memory _name,                   // token name, e.g. "SLAP Token"
  string memory _symbol,                 // token symbol, e.g. "SLAP"
  uint256 _pricePerTokenWei,             // price per WHOLE token in wei (0 => free)
  uint256 _maxSupplyWholeTokens,         // total cap in WHOLE tokens (decimals are 18)
  address _initialOwner,                 // owner address
  uint256 _walletMintCapWhole            // per-wallet cap in WHOLE tokens (0 => no cap)
)
```

> **Decimals:** 18.
> **Max supply** is enforced after converting whole tokens → smallest units.

### Admin functions

* `setPrice(uint256 newPriceWei)` — set price per **whole** token (in wei). `0` enables free mint.
* `setMintOpen(bool open)` — pause/unpause mint.
* `setTransfersEnabled(bool enabled)` — enable/disable wallet-to-wallet transfers.
* `setWalletMintCap(uint256 newCapWhole)` — set per-wallet cap in **whole** tokens. `0` = unlimited.
* `withdraw(address payable to)` — withdraw native currency from the contract (owner only).

### Read functions

* `pricePerTokenWei()` — current mint price (wei per whole token)
* `maxSupply()` — hard cap in **smallest units**
* `mintOpen()` — bool
* `transfersEnabled()` — bool
* `walletMintCap()` — whole-token cap per wallet
* `mintedWhole(address)` — how many **whole** tokens a wallet minted via `mint()`
* `tokensLeft()` — remaining supply (in whole tokens)
* standard ERC-20 views: `name()`, `symbol()`, `decimals()`, `totalSupply()`, `balanceOf()`, etc.

### Transfer gating

OpenZeppelin v5 uses the `_update` hook. This contract blocks transfers while `transfersEnabled == false`, but still allows **mint** (from `address(0)`) and **burn** (to `address(0)`):

```solidity
function _update(address from, address to, uint256 value)
    internal
    virtual
    override
{
    if (from != address(0) && to != address(0)) {
        require(transfersEnabled, "transfers disabled");
    }
    super._update(from, to, value);
}
```

---

## Troubleshooting

* **“Function has override specified but does not override anything”**
  You’re compiling with OZ **4.x** while the contract is written for **OZ 5.x**.
  Make sure `npm ls @openzeppelin/contracts` shows **5.x** and imports use:

  ```solidity
  import "@openzeppelin/contracts/utils/ReentrancyGuard.sol"; // v5 path
  ```
* **thirdweb CLI ‘device link’ warning / no browser opens**
  Set the secret key and pass `-k`:

  ```bash
  export THIRDWEB_SECRET_KEY="sk_live_..."
  npx thirdweb deploy -k "$THIRDWEB_SECRET_KEY"
  ```
* **Wrong network / chain mismatch**
  Ensure MetaMask is on the same chain you selected in the deploy UI.
* **Non-transferable after mint**
  That’s by design. Call `setTransfersEnabled(true)` once you want to allow transfers.

---

## Notes

* This repo intentionally keeps **only one contract file** in `contracts/` when building with thirdweb to avoid compiling legacy files.
* If you need an OZ **4.9** version, switch imports and use the `_beforeTokenTransfer` hook instead of `_update`.

---

## License

[MIT](./LICENSE) — do whatever, but no liability.

---
