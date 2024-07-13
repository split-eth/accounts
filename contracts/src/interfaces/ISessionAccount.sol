// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ISessionAccount {
    function startSession(address sessionAddress, uint48 duration) external;
}