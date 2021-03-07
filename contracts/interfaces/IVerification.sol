// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

interface IVerification {
    function isUser(address _user) external view returns(bool);
}