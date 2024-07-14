// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { Utils } from "./utils/Utils.sol";
import { Signatures } from "./utils/Signatures.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { INonceManager } from "@account-abstraction/contracts/interfaces/INonceManager.sol";
import { IEntryPoint } from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";

// 4337
import { EntryPoint } from "@cloned/entrypoint/core/EntryPoint.sol";
import { TokenEntryPoint } from "../src/4337/TokenEntryPoint.sol";
import { Paymaster } from "../src/4337/Paymaster.sol";
import { ITokenEntryPoint } from "../src/4337/interfaces/ITokenEntryPoint.sol";
import { UserOperationLib, UserOperation } from "@account-abstraction/contracts/interfaces/UserOperation.sol";

import { SessionAccountManager } from "../src/SessionAccountManager.sol";
import { SessionAccount } from "../src/SessionAccount.sol";
import { MyToken } from "../src/tokens/MyToken.sol";

contract SessionAccountManagerTest is Test {
	using UserOperationLib for UserOperation;

	Signatures internal signatures = new Signatures();

	SessionAccountManager public sessionAccountManager;
	EntryPoint public entryPoint;
	TokenEntryPoint public tokenEntryPoint;
	Paymaster public paymaster;
	MyToken public token;
	address public proxy;

	Utils internal utils;

	address payable[] internal users;
	// address internal sponsor;
	address internal owner;
	address internal admin;
	address internal provider;

	address internal user1;
	uint256 internal user1PK;

	address internal sponsor1;
	uint256 internal sponsor1PK;

	address internal session1;
	uint256 internal session1PK;

	SessionAccount internal account1;

	function setUp() public {
		utils = new Utils();
		users = utils.createUsers(4);
		// sponsor = users[0];
		// vm.label(sponsor, "Sponsor");
		owner = users[1];
		vm.label(owner, "Owner");
		admin = users[2];
		vm.label(admin, "Admin");
		provider = users[3];
		vm.label(provider, "Provider");

		user1PK = vm.envUint("PRIVATE_KEY");
		user1 = vm.envAddress("ACCOUNT_ADDRESS");
		vm.label(user1, "Provider");

		sponsor1PK = vm.envUint("SPONSOR_PRIVATE_KEY");
		sponsor1 = vm.envAddress("SPONSOR_ACCOUNT_ADDRESS");
		vm.label(sponsor1, "Sponsor1");

		session1PK = vm.envUint("SESSION_PRIVATE_KEY");
		session1 = vm.envAddress("SESSION_ACCOUNT_ADDRESS");
		vm.label(session1, "Session1");

		vm.startPrank(owner);

		// deploy 4337
		entryPoint = new EntryPoint();

		address implementation = address(new Paymaster());
		bytes memory data = abi.encodeCall(Paymaster.initialize, (owner, sponsor1));

		proxy = address(new ERC1967Proxy(implementation, data));

		paymaster = Paymaster(proxy);

		implementation = address(new MyToken());
		data = abi.encodeCall(MyToken.initialize, ("MyToken", "MTK"));

		proxy = address(new ERC1967Proxy(implementation, data));

		token = MyToken(proxy);

		implementation = address(new TokenEntryPoint(INonceManager(address(entryPoint))));
		address[] memory whitelisted = new address[](1);

		data = abi.encodeCall(TokenEntryPoint.initialize, (owner, address(paymaster), whitelisted));
		proxy = address(new ERC1967Proxy(implementation, data));

		tokenEntryPoint = TokenEntryPoint(proxy);

		// deploy SessionAccountManager
		implementation = address(new SessionAccountManager());
		uint48 sessionDuration = 30 days;
		data = abi.encodeCall(
			SessionAccountManager.initialize,
			(IEntryPoint(address(entryPoint)), ITokenEntryPoint(tokenEntryPoint), owner, sessionDuration)
		);

		proxy = address(new ERC1967Proxy(implementation, data));

		sessionAccountManager = SessionAccountManager(proxy);

		whitelisted = new address[](2);
		whitelisted[0] = address(sessionAccountManager);
		whitelisted[1] = address(token);

		tokenEntryPoint.updateWhitelist(whitelisted);

		account1 = sessionAccountManager.createAccount(
			provider,
			sessionAccountManager.getAccountSalt("test@provider.com")
		);

		token.mint(address(account1), 100);

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
		SessionAccount account = sessionAccountManager.createAccount(provider, salt);
		address counterfactual = sessionAccountManager.getAddress(provider, salt);

		assertTrue(address(account) != address(0));
		assertEq(address(account), counterfactual);
	}

	// function testSession() public {
	// 	account1.startSession(address(this), 30 days);

	// 	token.transfer(address(account1), 10);

	// 	balance = token.balanceOf(address(account1));
	// 	assertEq(balance, 110);

	// }

	function testNormalTransaction() public {
		vm.startPrank(owner);

		token.mint(address(user1), 100);

		vm.stopPrank();

		uint256 balance = token.balanceOf(address(user1));
		assertEq(balance, 100);

		vm.startPrank(user1);

		token.transfer(address(account1), 10);

		vm.stopPrank();

		balance = token.balanceOf(address(account1));
		assertEq(balance, 110);
	}

	function testNormal4337Transaction() public {
		vm.startPrank(owner);

		token.mint(address(user1), 100);

		vm.stopPrank();

		uint256 balance = token.balanceOf(address(user1));
		assertEq(balance, 100);

		vm.startPrank(sponsor1);

		bytes memory initCode = new bytes(0);

		bytes memory callData = abi.encodeWithSignature("transfer(address,uint256)", address(user1), 10);
		bytes memory userOpCallData = abi.encodeWithSignature(
			"execute(address,uint256,bytes)",
			address(token),
			0,
			callData
		);

		UserOperation memory op = UserOperation({
			sender: address(account1),
			nonce: 0,
			initCode: initCode,
			callData: userOpCallData,
			callGasLimit: 0,
			verificationGasLimit: 0,
			preVerificationGas: 0,
			maxFeePerGas: 0,
			maxPriorityFeePerGas: 0,
			paymasterAndData: new bytes(0),
			signature: new bytes(0)
		});

		uint48 validUntil = uint48(block.timestamp + 30 days);
		uint48 validAfter = uint48(block.timestamp);

		// Get the current block timestamp
		uint256 currentTimestamp = block.timestamp;

		// Advance time by 1 second
		vm.warp(currentTimestamp + 1);

		bytes32 paymasterDataHash = signatures.getEthSignedMessageHash(paymaster.getHash(op, validUntil, validAfter));

		(uint8 v, bytes32 r, bytes32 s) = vm.sign(sponsor1PK, paymasterDataHash);

		bytes memory paymasterAndData = abi.encodePacked(
			address(paymaster),
			abi.encode(validUntil, validAfter),
			signatures.joinSignature(r, s, v)
		);

		op.paymasterAndData = paymasterAndData;

		bytes32 opHash = signatures.getEthSignedMessageHash(tokenEntryPoint.getUserOpHash(op));

		(v, r, s) = vm.sign(user1PK, opHash);

		op.signature = signatures.joinSignature(r, s, v);

		UserOperation[] memory ops = new UserOperation[](1);
		ops[0] = op;

		vm.expectRevert();
		tokenEntryPoint.handleOps(ops, payable(0));

		vm.stopPrank();

		balance = token.balanceOf(address(user1));
		assertEq(balance, 100);
	}

	function testSession4337Transaction() public {
		vm.startPrank(owner);

		token.mint(address(user1), 100);

		vm.stopPrank();

		uint256 balance = token.balanceOf(address(user1));
		assertEq(balance, 100);

		vm.startPrank(provider);

		// TODO: proper test case where everything is signed correctly
		account1.startSession(session1, 30 days);

		vm.stopPrank();

		vm.startPrank(sponsor1);

		bytes memory initCode = new bytes(0);

		bytes memory callData = abi.encodeWithSignature("transfer(address,uint256)", address(user1), 10);
		bytes memory userOpCallData = abi.encodeWithSignature(
			"execute(address,uint256,bytes)",
			address(token),
			0,
			callData
		);

		UserOperation memory op = UserOperation({
			sender: address(account1),
			nonce: 0,
			initCode: initCode,
			callData: userOpCallData,
			callGasLimit: 0,
			verificationGasLimit: 0,
			preVerificationGas: 0,
			maxFeePerGas: 0,
			maxPriorityFeePerGas: 0,
			paymasterAndData: new bytes(0),
			signature: new bytes(0)
		});

		uint48 validUntil = uint48(block.timestamp + 30 days);
		uint48 validAfter = uint48(block.timestamp);

		// Get the current block timestamp
		uint256 currentTimestamp = block.timestamp;

		// Advance time by 1 second
		vm.warp(currentTimestamp + 1);

		bytes32 paymasterDataHash = signatures.getEthSignedMessageHash(paymaster.getHash(op, validUntil, validAfter));

		(uint8 v, bytes32 r, bytes32 s) = vm.sign(sponsor1PK, paymasterDataHash);

		bytes memory paymasterAndData = abi.encodePacked(
			address(paymaster),
			abi.encode(validUntil, validAfter),
			signatures.joinSignature(r, s, v)
		);

		op.paymasterAndData = paymasterAndData;

		bytes32 opHash = signatures.getEthSignedMessageHash(tokenEntryPoint.getUserOpHash(op));

		(v, r, s) = vm.sign(session1PK, opHash);

		op.signature = signatures.joinSignature(r, s, v);

		UserOperation[] memory ops = new UserOperation[](1);
		ops[0] = op;

		tokenEntryPoint.handleOps(ops, payable(0));

		vm.stopPrank();

		balance = token.balanceOf(address(user1));
		assertEq(balance, 110);
	}
}
