// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract SelfAuthorized {
    function requireSelfCall() private view{
        require (msg.sender == address(this), "Method can only be called form this contract");
    }
    modifier authorized {
        // Modifiers are copied around during compilation. This is a function call as it minimized the bytecode size
        requireSelfCall();
        _;
    }
}