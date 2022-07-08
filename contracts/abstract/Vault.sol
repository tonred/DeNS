pragma ton-solidity >= 0.61.2;

import "../utils/Gas.sol";

import "@broxus/contracts/contracts/libraries/MsgFlag.sol";
import "ton-eth-bridge-token-contracts/contracts/interfaces/ITokenRoot.sol";
import "ton-eth-bridge-token-contracts/contracts/interfaces/ITokenWallet.sol";
import "ton-eth-bridge-token-contracts/contracts/interfaces/IAcceptTokensTransferCallback.sol";


abstract contract Vault is IAcceptTokensTransferCallback {

    address public _token;
    address public _wallet;
    uint128 public _balance;

    modifier onlyToken() {
        require(msg.sender == _token && _token.value != 0, 69);
        _;
    }

    modifier onlyWallet() {
        require(msg.sender == _wallet && _wallet.value != 0, 69);
        _;
    }

    constructor(address token) internal {
        _token = token;
        ITokenRoot(token).deployWallet{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED,
            callback: onWalletDeployed
        }({
            owner: address(this),
            deployWalletValue: Gas.DEPLOY_WALLET_VALUE
        });
    }

    function onWalletDeployed(address wallet) public onlyToken {
        _wallet = wallet;
    }

    function getToken() public view responsible returns (address token) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _token;
    }

    function getWallet() public view responsible returns (address wallet) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _wallet;
    }

    function getBalance() public view responsible returns (uint128 balance) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _balance;
    }

    function _transferTokens(uint128 amount, address recipient, TvmCell payload) internal {
        _balance -= amount;
        ITokenWallet(_wallet).transfer{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED,
            bounce: false
        }({
            amount: amount,
            recipient: recipient,
            deployWalletValue: 0,
            remainingGasTo: recipient,
            notify: true,
            payload: payload
        });
    }

}
