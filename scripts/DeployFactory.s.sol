// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {TransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/TransparentProxyFactory.sol';

library DeployFactory {
  bytes32 constant salt = keccak256(bytes('transparentProxyFactory'));

  function _create2Factory(address admin) internal returns (address) {
    TransparentProxyFactory factory = new TransparentProxyFactory{salt: salt}();
    return factory.createProxyAdmin(admin);
  }
}

contract DeployMainnet is Script {
  function run() external {
    vm.startBroadcast();
    DeployFactory._create2Factory(AaveGovernanceV2.SHORT_EXECUTOR);
    vm.stopBroadcast();
  }
}

contract DeployPolygon is Script {
  function run() external {
    vm.startBroadcast();
    DeployFactory._create2Factory(AaveGovernanceV2.POLYGON_BRIDGE_EXECUTOR);
    vm.stopBroadcast();
  }
}

contract DeployOptimism is Script {
  function run() external {
    vm.startBroadcast();
    DeployFactory._create2Factory(AaveGovernanceV2.OPTIMISM_BRIDGE_EXECUTOR);
    vm.stopBroadcast();
  }
}

contract DeployArbitrum is Script {
  function run() external {
    vm.startBroadcast();
    DeployFactory._create2Factory(AaveGovernanceV2.ARBITRUM_BRIDGE_EXECUTOR);
    vm.stopBroadcast();
  }
}

contract DeployAvalanche is Script {
  function run() external {
    vm.startBroadcast();
    DeployFactory._create2Factory(0xa35b76E4935449E33C56aB24b23fcd3246f13470); // guardian
    vm.stopBroadcast();
  }
}

contract DeployFantom is Script {
  function run() external {
    vm.startBroadcast();
    DeployFactory._create2Factory(0x39CB97b105173b56b5a2b4b33AD25d6a50E6c949); // guardian
    vm.stopBroadcast();
  }
}

contract DeployHarmony is Script {
  function run() external {
    vm.startBroadcast();
    DeployFactory._create2Factory(0xb2f0C5f37f4beD2cB51C44653cD5D84866BDcd2D); // guardian
    vm.stopBroadcast();
  }
}
