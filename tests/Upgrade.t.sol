// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import 'forge-std/Test.sol';

import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {GovV3Helpers} from 'aave-helpers/GovV3Helpers.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {IRewardsController} from 'aave-v3-periphery/contracts/rewards/interfaces/IRewardsController.sol';
import {UpgradePayload} from '../src/UpgradePayload.sol';
import {StaticATokenFactory} from '../src/StaticATokenFactory.sol';
import {StaticATokenLM} from '../src/StaticATokenLM.sol';
import {ITransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/interfaces/ITransparentProxyFactory.sol';
import {TransparentUpgradeableProxy} from 'solidity-utils/contracts/transparent-proxy/TransparentUpgradeableProxy.sol';
import {DeployUpgrade} from '../scripts/DeployUpgrade.s.sol';

abstract contract UpgradePayloadTest is Test {
  string public NETWORK;
  uint256 public immutable BLOCK_NUMBER;

  UpgradePayload internal payload;

  constructor(string memory network, uint256 blocknumber) {
    NETWORK = network;
    BLOCK_NUMBER = blocknumber;
  }

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl(NETWORK), BLOCK_NUMBER);
    payload = _getPayload();
  }

  function _getPayload() internal virtual returns (UpgradePayload);

  function test_upgrade() external {
    GovV3Helpers.executePayload(vm, address(payload));

    address newImpl = payload.FACTORY().STATIC_A_TOKEN_IMPL();

    // check factory is updated
    assertEq(newImpl, payload.NEW_TOKEN_IMPLEMENTATION());
    // check all tokens are updated
    address[] memory tokens = payload.FACTORY().getStaticATokens();
    vm.startPrank(address(payload.ADMIN()));
    for (uint256 i = 0; i < tokens.length; i++) {
      assertEq(
        TransparentUpgradeableProxy(payable(tokens[i])).implementation(),
        payload.NEW_TOKEN_IMPLEMENTATION()
      );
    }
  }

  function test_validateDomainSeparator() public {
    GovV3Helpers.executePayload(vm, address(payload));

    address[] memory staticATokens = payload.FACTORY().getStaticATokens();
    for (uint256 i = 0; i < staticATokens.length; i++) {
      bytes32 separator1 = StaticATokenLM(staticATokens[i]).DOMAIN_SEPARATOR();
      for (uint256 j = 0; j < staticATokens.length; j++) {
        if (i != j) {
          bytes32 separator2 = StaticATokenLM(staticATokens[j]).DOMAIN_SEPARATOR();
          assertNotEq(separator1, separator2, 'DOMAIN_SEPARATOR_MUST_BE_UNIQUE');
        }
      }
    }
  }
}

contract UpgradeMainnetTest is UpgradePayloadTest('mainnet', 19376575) {
  function _getPayload() internal virtual override returns (UpgradePayload) {
    return DeployUpgrade.deployMainnet();
  }
}

contract UpgradePolygonTest is UpgradePayloadTest('polygon', 54337710) {
  function _getPayload() internal virtual override returns (UpgradePayload) {
    return DeployUpgrade.deployPolygon();
  }
}

contract UpgradeAvalancheTest is UpgradePayloadTest('avalanche', 42590450) {
  function _getPayload() internal virtual override returns (UpgradePayload) {
    return DeployUpgrade.deployAvalanche();
  }
}

contract UpgradeArbitrumTest is UpgradePayloadTest('arbitrum', 187970620) {
  function _getPayload() internal virtual override returns (UpgradePayload) {
    return DeployUpgrade.deployArbitrum();
  }
}

contract UpgradeOptimismTest is UpgradePayloadTest('optimism', 117104603) {
  function _getPayload() internal virtual override returns (UpgradePayload) {
    return DeployUpgrade.deployOptimism();
  }
}

contract UpgradeMetisTest is UpgradePayloadTest('metis', 14812943) {
  function _getPayload() internal virtual override returns (UpgradePayload) {
    return DeployUpgrade.deployMetis();
  }
}

contract UpgradeBNBTest is UpgradePayloadTest('bnb', 36989356) {
  function _getPayload() internal virtual override returns (UpgradePayload) {
    return DeployUpgrade.deployBNB();
  }
}

contract UpgradeScrollTest is UpgradePayloadTest('scroll', 3921934) {
  function _getPayload() internal virtual override returns (UpgradePayload) {
    return DeployUpgrade.deployScroll();
  }
}

contract UpgradeBaseTest is UpgradePayloadTest('base', 11985792) {
  function _getPayload() internal virtual override returns (UpgradePayload) {
    return DeployUpgrade.deployBase();
  }
}

contract UpgradeGnosisTest is UpgradePayloadTest('gnosis', 32991586) {
  function _getPayload() internal virtual override returns (UpgradePayload) {
    return DeployUpgrade.deployGnosis();
  }
}
