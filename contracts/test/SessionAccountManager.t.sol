// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { Utils } from "./utils/Utils.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { INonceManager } from "@account-abstraction/contracts/interfaces/INonceManager.sol";
import { IEntryPoint } from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";

// 4337
import { EntryPoint } from "@cloned/entrypoint/core/EntryPoint.sol";
import { TokenEntryPoint } from "../src/4337/TokenEntryPoint.sol";
import { Paymaster } from "../src/4337/Paymaster.sol";
import { ITokenEntryPoint } from "../src/4337/interfaces/ITokenEntryPoint.sol";

import { SessionAccountManager } from "../src/SessionAccountManager.sol";
import { SessionAccount } from "../src/SessionAccount.sol";

contract SessionAccountManagerTest is Test {
	SessionAccountManager public sessionAccountManager;
	EntryPoint public entryPoint;
	TokenEntryPoint public tokenEntryPoint;
	Paymaster public paymaster;
	address public proxy;

	Utils internal utils;

	address payable[] internal users;
	address internal sponsor;
	address internal owner;
	address internal admin;
	address internal provider;
	address internal user1;

	function setUp() public {
		utils = new Utils();
		users = utils.createUsers(5);
		sponsor = users[0];
		vm.label(sponsor, "Sponsor");
		owner = users[1];
		vm.label(owner, "Owner");
		admin = users[2];
		vm.label(admin, "Admin");
		provider = users[2];
		vm.label(provider, "Provider");
		user1 = users[2];
		vm.label(user1, "Provider");

		vm.startPrank(owner);

		// deploy 4337
		entryPoint = new EntryPoint();

		address implementation = address(new Paymaster());
		bytes memory data = abi.encodeCall(Paymaster.initialize, (owner, sponsor));

		proxy = address(new ERC1967Proxy(implementation, data));

		paymaster = Paymaster(proxy);

		implementation = address(new TokenEntryPoint(INonceManager(address(entryPoint))));
		address[] memory whitelisted = new address[](1);

		data = abi.encodeCall(TokenEntryPoint.initialize, (owner, address(paymaster), whitelisted));
		proxy = address(new ERC1967Proxy(implementation, data));

		tokenEntryPoint = TokenEntryPoint(proxy);

		// deploy SessionAccountManager
		implementation = address(new SessionAccountManager());
		uint48 sessionDuration = 30 days;
		data = abi.encodeCall(SessionAccountManager.initialize, (IEntryPoint(address(entryPoint)), ITokenEntryPoint(tokenEntryPoint), owner, sessionDuration));

		proxy = address(new ERC1967Proxy(implementation, data));

		sessionAccountManager = SessionAccountManager(proxy);

		whitelisted = new address[](1);
		whitelisted[0] = address(sessionAccountManager);

		tokenEntryPoint.updateWhitelist(whitelisted);

		vm.stopPrank();
	}

	function testOwner() public view {
		assertEq(sessionAccountManager.owner(), owner);
	}

	function testWhitelisted() public view {
		assertTrue(tokenEntryPoint.isWhitelisted(address(sessionAccountManager)));
	}

	function testAccountCreation() public {
		bytes32 salt = sessionAccountManager.getAccountSalt("test");
		SessionAccount account = sessionAccountManager.createAccount(provider, user1, salt);
		address counterfactual = sessionAccountManager.getAddress(provider, user1, salt);

		assertTrue(address(account) != address(0));
		assertEq(address(account), counterfactual);
	}

	// function testRoleSetup() public {
	// 	assertEq(badgeCollection.hasRole(badgeCollection.BADGE_COLLECTION_ADMIN_ROLE(), owner), true);
	// 	assertEq(badgeCollection.hasRole(badgeCollection.BADGE_COLLECTION_ADMIN_ROLE(), admin), true);

	// 	vm.startPrank(owner);
	// 	badgeCollection.revokeRole(badgeCollection.BADGE_COLLECTION_ADMIN_ROLE(), admin);
	// 	vm.stopPrank();

	// 	assertEq(badgeCollection.hasRole(badgeCollection.BADGE_COLLECTION_ADMIN_ROLE(), admin), false);
	// }

	// function testCreateBadge() public {
	// 	uint256 id = 1;
	// 	uint48 claimFrom = uint48(block.timestamp);
	// 	uint48 claimTo = uint48(block.timestamp + 7 days);
	// 	uint256 maxClaim = 100;
	// 	uint48 updateUntil = uint48(block.timestamp + 30 days);
	// 	string memory _uri = "https://example.com/token-metadata.json";

	// 	vm.startPrank(admin);
	// 	badgeCollection.create(id, claimFrom, claimTo, maxClaim, updateUntil, _uri);
	// 	vm.stopPrank();

	// 	(
	// 		uint48 returnedClaimFrom,
	// 		uint48 returnedClaimTo,
	// 		uint256 returnedMaxClaim,
	// 		uint48 returnedUpdateUntil,
	// 		string memory returnedUri
	// 	) = badgeCollection.get(id);

	// 	// check that they are equal
	// 	assertEq(returnedClaimFrom, claimFrom);
	// 	assertEq(returnedClaimTo, claimTo);
	// 	assertEq(returnedMaxClaim, maxClaim);
	// 	assertEq(returnedUpdateUntil, updateUntil);
	// 	assertEq(returnedUri, _uri);

	// 	// check that the uri is set
	// 	assertEq(badgeCollection.uri(id), _uri);
	// }
}
