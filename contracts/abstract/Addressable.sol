pragma ton-solidity >= 0.57.3;


abstract contract Addressable {

    address public _root;
    TvmCell public _platformCode;


    modifier onlyRoot() {
        require(msg.sender == _root, 69);
        _;
    }

    modifier onlyCertificate(string path) {
        address certificate = _certificateAddress(path);
        require(msg.sender == certificate, 69);
        _;
    }

//    modifier onlyNft(uint256 id) {
//        address nft = _nftAddress(id);
//        require(msg.sender == nft, 69);
//        _;
//    }


    function getRoot() public responsible returns (address root) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _root;
    }

//    function _nftAddress(uint256 id) internal returns (address) {
//        TvmCell stateInit = _buildNftStateInit(path);
//        return calcAddress(stateInit);
//    }

    function _certificateAddress(string path) internal returns (address) {
        TvmCell stateInit = _buildCertificateStateInit(path);
        return calcAddress(stateInit);
    }

//    function _buildNftStateInit(uint256 id) internal view returns (TvmCell) {
//        TvmCell initialData = abi.encode(id);
//        return _buildPlatformStateInit(PlatformType.NFT, initialData);
//    }

    function _buildCertificateStateInit(string path) internal view returns (TvmCell) {
        TvmCell initialData = abi.encode(path);
        return _buildPlatformStateInit(PlatformType.CERTIFICATE, initialData);
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
