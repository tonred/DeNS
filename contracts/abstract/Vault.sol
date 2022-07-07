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

    // todo getters

    constructor(address token) internal {
        _token = token;
        ITokenRoot(token).deployWallet{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED,  // todo value
            callback: onWalletDeployed
        }({
            owner: address(this),
            deployWalletValue: Gas.DEPLOY_WALLET_VALUE
        });
    }

    function onWalletDeployed(address wallet) public {
        require(msg.sender == _token && _token.value != 0 && _wallet.value == 0, 69);
        _wallet = wallet;
    }

    function _transferTokens(uint128 amount, address recipient, TvmCell payload) internal {
        _balance -= amount;
        ITokenWallet(_wallet).transfer{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED,  // todo value
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
