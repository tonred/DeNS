pragma ton-solidity >= 0.61.2;

import "../platform/Platform.sol";
import "../platform/PlatformType.sol";


abstract contract Addressable {

    address public _root;
    TvmCell public _platformCode;


    modifier onlyRoot() {
        require(msg.sender == _root, 69);
        _;
    }

    function getRoot() public view responsible returns (address root) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _root;
    }


    function _nftAddressByName(address collection, string name) internal view returns (address) {
        uint256 id = tvm.hash(name);
        return _nftAddress(collection, id);
    }

    function _nftAddress(address collection, uint256 id) internal view returns (address) {
        TvmCell stateInit = _buildNftStateInit(collection, id);
        return calcAddress(stateInit);
    }

    function _domainAddress(string name) internal view returns (address) {
        TvmCell stateInit = _buildDomainStateInit(name);
        return calcAddress(stateInit);
    }

    function _buildNftStateInit(address collection, uint256 id) internal view returns (TvmCell) {
        TvmCell initialData = abi.encode(collection, id);
        return _buildPlatformStateInit(PlatformType.NFT, initialData);
    }

    function _buildDomainStateInit(string name) internal view returns (TvmCell) {
        TvmCell initialData = abi.encode(name);
        return _buildPlatformStateInit(PlatformType.DOMAIN, initialData);
    }

    function _buildPlatformStateInit(PlatformType platformType, TvmCell initialData) private view returns (TvmCell) {
        return tvm.buildStateInit({
            contr: Platform,
            varInit: {
                root: _root,
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
