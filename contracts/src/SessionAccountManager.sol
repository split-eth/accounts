// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IEntryPoint } from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";

import { SessionAccount } from "./SessionAccount.sol";
import { ITokenEntryPoint } from "./4337/interfaces/ITokenEntryPoint.sol";

/**
 * @title SessionAccountManager
 * @dev Contract for creating new accounts and calculating their counterfactual addresses.
 *
 * https://github.com/eth-infinitism/account-abstraction/blob/abff2aca61a8f0934e533d0d352978055fddbd96/contracts/samples/SimpleSessionAccountFactory.sol
 */
contract SessionAccountManager is Initializable, OwnableUpgradeable, UUPSUpgradeable {
	/// @custom:oz-upgrades-unsafe-allow state-variable-immutable
	SessionAccount public accountImplementation;
	uint48 public sessionDuration;

	event AccountCreated(address indexed account);

	/// @custom:oz-upgrades-unsafe-allow constructor
	constructor() {
		_disableInitializers();
	}

	function initialize(
		IEntryPoint _entryPoint,
		ITokenEntryPoint _tokenEntryPoint,
		address anOwner,
		uint48 _sessionDuration
	) public virtual initializer {
		__Ownable_init(anOwner);
		__UUPSUpgradeable_init();

		accountImplementation = new SessionAccount(_entryPoint, _tokenEntryPoint);
		sessionDuration = _sessionDuration;
	}

	function getAccountSalt(string calldata otherFactory) public pure returns (bytes32) {
		return keccak256(abi.encodePacked(otherFactory));
	}

	function getAccountHash(address provider, bytes32 salt) public pure returns (bytes32) {
		return keccak256(abi.encodePacked(provider, salt));
	}

	/**
	 * create an account, and return its address.
	 * returns the address even if the account is already deployed.
	 * Note that during UserOperation execution, this method is called only if the account is not deployed.
	 * This method returns an existing account address so that entryPoint.getSenderAddress() would work even after account creation
	 */
	function createAccount(address provider, bytes32 salt) public returns (SessionAccount ret) {
		address addr = getAddress(provider, salt);

		emit AccountCreated(addr);

		uint codeSize = addr.code.length;
		if (codeSize > 0) {
			return SessionAccount(payable(addr));
		}

		bytes32 accountHash = getAccountHash(provider, salt);

		ret = SessionAccount(
			payable(
				new ERC1967Proxy{ salt: accountHash }(
					address(accountImplementation),
					abi.encodeCall(SessionAccount.initialize, (provider, address(this)))
				)
			)
		);
	}

	/**
	 * calculate the counterfactual address of this account as it would be returned by createAccount()
	 */
	function getAddress(address provider, bytes32 salt) public view returns (address) {
		bytes32 accountHash = getAccountHash(provider, salt);

		return
			Create2.computeAddress(
				accountHash,
				keccak256(
					abi.encodePacked(
						type(ERC1967Proxy).creationCode,
						abi.encode(
							address(accountImplementation),
							abi.encodeCall(SessionAccount.initialize, (provider, address(this)))
						)
					)
				)
			);
	}

	error InvalidSignature();

	function startSession(
		address provider,
		bytes32 salt,
		address sessionAddress,
		bytes memory providerSignature,
		bytes memory signature
	) public {
		bytes32 accountHash = getAccountHash(provider, salt);

		address providerSigner = recoverSigner(accountHash, providerSignature);
		address sessionSigner = recoverSigner(accountHash, signature);

		if (providerSigner != provider || sessionSigner != sessionAddress) {
			revert InvalidSignature();
		}

		address accountAddress = getAddress(provider, salt);
		uint codeSize = accountAddress.code.length;
		if (codeSize == 0) {
			createAccount(provider, salt);
		}

		SessionAccount account = SessionAccount(payable(accountAddress));

		account.startSession(sessionAddress, sessionDuration);
	}

	function readBytes32(bytes memory data, uint256 index) internal pure returns (bytes32 result) {
		require(data.length >= index + 32, "readBytes32: invalid data length");
		assembly {
			result := mload(add(data, add(32, index)))
		}
	}

		/**
	 * @notice Recover the signer of hash, assuming it's an EOA account
	 * @dev Only for EthSign signatures
	 * @param _hash       Hash of message that was signed
	 * @param _signature  Signature encoded as (bytes32 r, bytes32 s, uint8 v)
	 */
	function recoverSigner(bytes32 _hash, bytes memory _signature) internal pure returns (address signer) {
		require(_signature.length == 65, "SignatureValidator#recoverSigner: invalid signature length");

		// Variables are not scoped in Solidity.
		uint8 v = uint8(_signature[64]);
		bytes32 r = readBytes32(_signature, 0);
		bytes32 s = readBytes32(_signature, 32);

		// EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
		// unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
		// the valid range for s in (281): 0 < s < secp256k1n ÷ 2 + 1, and for v in (282): v ∈ {27, 28}. Most
		// signatures from current libraries generate a unique signature with an s-value in the lower half order.
		//
		// If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
		// with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
		// vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
		// these malleable signatures as well.
		//
		// Source OpenZeppelin
		// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/cryptography/ECDSA.sol

		if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
			revert("SignatureValidator#recoverSigner: invalid signature 's' value");
		}

		if (v != 27 && v != 28) {
			revert("SignatureValidator#recoverSigner: invalid signature 'v' value");
		}

		// Recover ECDSA signer
		signer = ecrecover(_hash, v, r, s);

		// Prevent signer from being 0x0
		require(signer != address(0x0), "SignatureValidator#recoverSigner: INVALID_SIGNER");

		return signer;
	}

	function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
		(newImplementation);
	}
}
