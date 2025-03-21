// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

interface IOptimismCrossDomainMessenger {
    function sendMessage(address _target, bytes calldata _message, uint32 _minGasLimit) external payable;
}

interface IL1CrossDomainMessenger {
    function xDomainMessageSender() external view returns (address);
}
