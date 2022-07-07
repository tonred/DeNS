pragma ton-solidity >= 0.61.2;

import "../platform/Platform.sol";
import "../platform/PlatformType.sol";

import "@broxus/contracts/contracts/libraries/MsgFlag.sol";


abstract contract Addressable {  // todo rename + see usage

    address public _root;
    TvmCell public _platformCode;


    modifier onlyRoot() {
        require(msg.sender == _root, 69);
        _;
    }

    function getRoot() public view responsible returns (address root) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _root;
    }


    function _certificateAddress(string path) internal view returns (address) {
        uint256 id = tvm.hash(path);
        return _certificateAddressByID(id);
    }

    function _certificateAddressByID(uint256 id) internal view returns (address) {
        TvmCell stateInit = _buildCertificateStateInit(id);
        return calcAddress(stateInit);
    }

    function _buildCertificateStateInit(uint256 id) internal view returns (TvmCell) {
        TvmCell initialData = abi.encode(id);
        return _buildPlatformStateInit(PlatformType.NFT, initialData);
    }

    function _buildPlatformStateInit(PlatformType platformType, TvmCell initialData) private view returns (TvmCell) {
        return tvm.buildStateInit({
            contr: Platform,
            varInit: {
                _root: _root,
                _platformType: uint8(platformType),
                _initialData: initialData
            },
            code: _platformCode
        });
    }

    function calcAddress(TvmCell stateInit) public pure returns (address) {
        return address(tvm.hash(stateInit));
    }

}
