// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import 'forge-std/Test.sol';

import {AaveMisc} from 'aave-address-book/AaveMisc.sol';
import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {GovHelpers} from 'aave-helpers/GovHelpers.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {IRewardsController} from 'aave-v3-periphery/contracts/rewards/interfaces/IRewardsController.sol';
import {UpgradePayload} from '../src/UpgradePayload.sol';
import {StaticATokenFactory} from '../src/StaticATokenFactory.sol';
import {StaticATokenLM} from '../src/StaticATokenLM.sol';
import {ITransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/interfaces/ITransparentProxyFactory.sol';

contract UpgradeTest is Test {
  address payload;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 17869617);
    StaticATokenLM staticToken = new StaticATokenLM(
      AaveV3Ethereum.POOL,
      IRewardsController(AaveV3Ethereum.DEFAULT_INCENTIVES_CONTROLLER)
    );
    payload = address(
      new UpgradePayload(
        AaveMisc.PROXY_ADMIN_ETHEREUM,
        AaveV3Ethereum.STATIC_A_TOKEN_FACTORY,
        address(
          new StaticATokenFactory(
            AaveV3Ethereum.POOL,
            AaveMisc.PROXY_ADMIN_ETHEREUM,
            ITransparentProxyFactory(AaveMisc.TRANSPARENT_PROXY_FACTORY_ETHEREUM),
            address(staticToken)
          )
        ),
        address(staticToken)
      )
    );
  }

  function test_upgrade() external {
    GovHelpers.executePayload(vm, payload, AaveGovernanceV2.SHORT_EXECUTOR);
  }
}
