---
name: solidity-foundry
description: "> Solidity smart contract development with Foundry — testing, deployment, gas optimization, OpenZeppelin patterns, prediction market contracts, ERC-4337 integration, and Chainlink oracle patterns. Use when writing, testing, auditing, or deploying Solidity contracts. Triggers on \"smart contract\", \"Solidity\", \"Foundry\", \"forge\", \"cast\", \"deploy contract\", \"ERC-20\", \"ERC-721\", \"prediction market contract\", \"oracle\", \"Chainlink\", \"Pyth\"."
version: 1.0.0
author: "Anthropic — ported for Hermes Agent by MADHATs"
license: "Anthropic skill licence; see upstream"
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Solidity, Foundry, Smart-Contracts, EVM, Testing, Gas]
    category: blockchain
    related_skills: [alchemy-api, agentic-gateway]
---

# Solidity + Foundry

Smart contract development for MAD Gambit on Base L2.

## Project Setup

```bash
# Init Foundry project
forge init mad-gambit-contracts
cd mad-gambit-contracts

# Install dependencies
forge install OpenZeppelin/openzeppelin-contracts
forge install smartcontractkit/chainlink
forge install foundry-rs/forge-std

# foundry.toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
optimizer = true
optimizer_runs = 200
solc_version = "0.8.24"

[rpc_endpoints]
base = "${BASE_RPC_URL}"
base_goerli = "${BASE_GOERLI_RPC_URL}"
```

## Contract Patterns

### Prediction Market (Base Pattern)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract MADMarket is ReentrancyGuard, Ownable, Pausable {
    uint256 public constant PLATFORM_FEE_BPS = 188; // 1.88%
    uint256 public constant CREATOR_SHARE_BPS = 4000; // 40%
    uint256 public constant COMMUNITY_SHARE_BPS = 2880; // 28.8% (display 28%)
    uint256 public constant BPS_DENOMINATOR = 10_000;

    struct Market {
        bytes32 questionId;
        address creator;
        uint256 totalVolume;
        uint256 resolutionTime;
        bool settled;
        uint8 winningOutcome;
    }

    mapping(bytes32 => Market) public markets;

    event MarketCreated(bytes32 indexed marketId, address indexed creator);
    event MarketSettled(bytes32 indexed marketId, uint8 winningOutcome);
    event FeesDistributed(bytes32 indexed marketId, uint256 platform, uint256 creator, uint256 community);

    function createMarket(
        bytes32 questionId,
        uint256 resolutionTime
    ) external whenNotPaused returns (bytes32 marketId) {
        require(resolutionTime > block.timestamp, "Resolution must be future");
        marketId = keccak256(abi.encodePacked(questionId, msg.sender, block.timestamp));
        markets[marketId] = Market({
            questionId: questionId,
            creator: msg.sender,
            totalVolume: 0,
            resolutionTime: resolutionTime,
            settled: false,
            winningOutcome: 0
        });
        emit MarketCreated(marketId, msg.sender);
    }

    function settleMarket(
        bytes32 marketId,
        uint8 outcome
    ) external onlyOwner nonReentrant {
        Market storage market = markets[marketId];
        require(!market.settled, "Already settled");
        require(block.timestamp >= market.resolutionTime, "Too early");

        market.settled = true;
        market.winningOutcome = outcome;

        // Checks-Effects-Interactions: state changes BEFORE external calls
        uint256 volume = market.totalVolume;
        uint256 platformFee = (volume * PLATFORM_FEE_BPS) / BPS_DENOMINATOR;
        uint256 creatorFee = (platformFee * CREATOR_SHARE_BPS) / BPS_DENOMINATOR;
        uint256 communityFee = (platformFee * COMMUNITY_SHARE_BPS) / BPS_DENOMINATOR;

        emit MarketSettled(marketId, outcome);
        emit FeesDistributed(marketId, platformFee, creatorFee, communityFee);

        // External calls LAST
        _distributeFees(market.creator, creatorFee, communityFee);
    }
}
```

### Chainlink VRF (Card Pack Randomness)

```solidity
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2Plus.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/IVRFCoordinatorV2Plus.sol";

contract MADPackOpener is VRFConsumerBaseV2Plus {
    IVRFCoordinatorV2Plus public coordinator;
    uint256 public subscriptionId;
    bytes32 public keyHash;

    mapping(uint256 => address) public requestToUser;

    function openPack(uint256 packTokenId) external returns (uint256 requestId) {
        requestId = coordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: subscriptionId,
                requestConfirmations: 3,
                callbackGasLimit: 200_000,
                numWords: 5, // 5 cards per pack
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({ nativePayment: false })
                )
            })
        );
        requestToUser[requestId] = msg.sender;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
        internal override
    {
        address user = requestToUser[requestId];
        // Use randomWords[0..4] to determine card rarities
        _mintCards(user, randomWords);
    }
}
```

## Foundry Testing

```solidity
// test/MADMarket.t.sol
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/MADMarket.sol";

contract MADMarketTest is Test {
    MADMarket market;
    address creator = makeAddr("creator");
    address user = makeAddr("user");

    function setUp() public {
        market = new MADMarket(address(this));
        vm.deal(user, 10 ether);
    }

    function test_CreateMarket() public {
        vm.prank(creator);
        bytes32 id = market.createMarket(keccak256("Will X happen?"), block.timestamp + 7 days);
        assertEq(market.markets(id).creator, creator);
    }

    function test_CannotSettleEarly() public {
        vm.prank(creator);
        bytes32 id = market.createMarket(keccak256("Q"), block.timestamp + 7 days);

        vm.expectRevert("Too early");
        market.settleMarket(id, 1);
    }

    function testFuzz_FeeCalculation(uint256 volume) public {
        volume = bound(volume, 1e6, 1e24); // 1 USDC to 1B USDC
        uint256 fee = (volume * 188) / 10_000;
        assertGt(fee, 0);
        assertLt(fee, volume);
    }
}
```

## Common Forge Commands

```bash
forge build                          # compile
forge test -vv                       # run tests verbose
forge test --match-test testSettle   # run specific test
forge coverage                       # coverage report
forge snapshot                       # gas snapshot
forge snapshot --check               # fail if gas increased
forge script script/Deploy.s.sol --rpc-url base --broadcast --verify
cast call $CONTRACT "getMarket(bytes32)" $MARKET_ID
cast send $CONTRACT "settleMarket(bytes32,uint8)" $ID 1 --private-key $PK
```

## Security Checklist

- [ ] Checks-Effects-Interactions on all state-changing functions
- [ ] `nonReentrant` on all external-call functions
- [ ] No `tx.origin` — use `msg.sender`
- [ ] Integer math uses Solidity 0.8+ overflow protection or explicit bounds
- [ ] All events emitted for off-chain indexing
- [ ] `Pausable` on market creation and settlement (emergency stop)
- [ ] Oracle answer validated: staleness check, reasonable bounds
- [ ] Foundry tests cover: happy path, revert cases, fuzz, invariant
