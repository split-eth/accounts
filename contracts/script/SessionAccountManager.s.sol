// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import { IEntryPoint } from "account-abstraction/interfaces/IEntryPoint.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { ITokenEntryPoint } from "../src/4337/interfaces/ITokenEntryPoint.sol";

import { Create2 } from "../src/Create2/Create2.sol";
import { SessionAccountManager } from "../src/SessionAccountManager.sol";

contract SessionAccountManagerDeploy is Script {
	function run() external {
		uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
		address owner = vm.envAddress("OWNER_ADDRESS");
		address entrypoint = vm.envAddress("ERC4337_ENTRYPOINT");
		// address tokenEntrypoint = vm.envAddress("ERC4337_TOKEN_ENTRYPOINT_BASE"); // BASE
		// address tokenEntrypoint = vm.envAddress("ERC4337_TOKEN_ENTRYPOINT_GNOSIS"); // GNOSIS
		address tokenEntrypoint = vm.envAddress("ERC4337_TOKEN_ENTRYPOINT_BASE_SEPOLIA"); // BASE SEPOLIA
		vm.startBroadcast(deployerPrivateKey);

		console.log("Finding Create2: ", vm.envAddress("CREATE2_FACTORY_ADDRESS"));

		Create2 deployer = Create2(vm.envAddress("CREATE2_FACTORY_ADDRESS"));

		bytes memory bytecode = getBytecode();

		bytes32 salt = keccak256(abi.encodePacked("ETHGLOBAL_BRUSSELS_2024_SESSION_ACCOUNT_MANAGER_2"));

		// Call eth_getCode to check the bytecode at the given address
		address contractAddress = deployer.computeAddress(salt, bytecode);
		bytes memory code = contractAddress.code;

		if (code.length > 0) {
			console.log("Contract is already deployed at address:", contractAddress);
		} else {
			console.log("Contract is not deployed at address:", contractAddress);
		}

		address cm = deployer.deploy(salt, bytecode);

		if (cm == address(0)) {
			console.log("SessionAccountManager deployment failed");

			vm.stopBroadcast();
			return;
		}

		console.log("SessionAccountManager created at: ", address(cm));

		uint48 sessionDuration = 30 days;

		address proxy = address(
			new ERC1967Proxy(
				cm,
				abi.encodeWithSelector(
					SessionAccountManager.initialize.selector,
					IEntryPoint(entrypoint),
					ITokenEntryPoint(tokenEntrypoint),
					owner,
					sessionDuration
				)
			)
		);

		console.log("SessionAccountManager proxy created at: ", proxy);

		vm.stopBroadcast();
	}

	function getBytecode() public pure returns (bytes memory) {
		bytes memory bytecode = type(SessionAccountManager).creationCode;
		return abi.encodePacked(bytecode);
	}
}
