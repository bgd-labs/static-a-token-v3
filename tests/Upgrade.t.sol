// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import 'forge-std/Test.sol';

import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {GovHelpers} from 'aave-helpers/GovHelpers.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {IRewardsController} from 'aave-v3-periphery/contracts/rewards/interfaces/IRewardsController.sol';
import {UpgradePayload} from '../src/UpgradePayload.sol';
import {StaticATokenFactory} from '../src/StaticATokenFactory.sol';
import {StaticATokenLM} from '../src/StaticATokenLM.sol';
import {ITransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/interfaces/ITransparentProxyFactory.sol';
import {TransparentUpgradeableProxy} from 'solidity-utils/contracts/transparent-proxy/TransparentUpgradeableProxy.sol';
import {DeployUpgrade} from '../scripts/DeployUpgrade.s.sol';

contract UpgradeTest is Test {
  UpgradePayload payload;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 17869617);
    payload = UpgradePayload(DeployUpgrade.deployMainnet());
  }

  function test_upgrade() external {
    GovHelpers.executePayload(vm, address(payload), AaveGovernanceV2.SHORT_EXECUTOR);

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
}
