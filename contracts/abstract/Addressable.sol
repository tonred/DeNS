pragma ton-solidity >= 0.61.2;

import "../platform/Platform.sol";
import "../platform/PlatformType.sol";


abstract contract Addressable {

    address public _root;
    address public _storage;
    TvmCell public _platformCode;


    modifier onlyRoot() {
        require(msg.sender == _root, 69);
        _;
    }

    function getRoot() public view responsible returns (address root) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _root;
    }


    function _deployCertificate(string path, uint128 value, TvmCell code, TvmCell params) internal view {
        TvmCell stateInit = buildCertificateStateInit(path);
        new Platform{
            stateInit: stateInit,
            value: value,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false
        }(code, params, address(0));
    }

    function _nftAddressByPath(address collection, string path) internal view returns (address) {
        uint256 id = tvm.hash(path);
        return _nftAddress(collection, id);
    }

    function _nftAddress(address collection, uint256 id) internal view returns (address) {
        TvmCell stateInit = _buildNftStateInit(collection, id);
        return calcAddress(stateInit);
    }

    function _certificateAddress(string path) internal view returns (address) {
        TvmCell stateInit = buildCertificateStateInit(path);
        return calcAddress(stateInit);
    }

    function _buildNftStateInit(address collection, uint256 id) internal view returns (TvmCell) {
        TvmCell initialData = abi.encode(collection, id);
        return _buildPlatformStateInit(PlatformType.NFT, initialData);
    }

    function buildCertificateStateInit(string path) internal view returns (TvmCell) {
        TvmCell initialData = abi.encode(path);
        return _buildPlatformStateInit(PlatformType.CERTIFICATE, initialData);
    }

    function _buildPlatformStateInit(PlatformType platformType, TvmCell initialData) private view returns (TvmCell) {
        return tvm.buildStateInit({
            contr: Platform,
            varInit: {
                root: _storage,
                platformType: uint8(platformType),
                initialData: initialData,
                platformCode: _platformCode
            },
            code: _platformCode
        });
    }

    function calcAddress(TvmCell stateInit) public pure returns (address) {
        return address(tvm.hash(stateInit));
    }

}
