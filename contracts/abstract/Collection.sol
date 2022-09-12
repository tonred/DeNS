pragma ever-solidity ^0.63.0;

import "../interfaces/outer/IOwner.sol";
import "../platform/PlatformType.sol";
import "../platform/Platform.sol";
import "../utils/TransferUtils.sol";

import "tip4/contracts/implementation/4_2/JSONMetadataBase.sol";
import "tip4/contracts/implementation/4_3/CollectionBase4_3.sol";


abstract contract Collection is CollectionBase4_3, JSONMetadataBase, TransferUtils {

    TvmCell public _platformCode;

    modifier onlyCertificateByID(uint256 id) {
        address nft = _certificateAddressByID(id);
        require(msg.sender == nft, ErrorCodes.IS_NOT_CERTIFICATE);
        _;
    }


    constructor(
        TvmCell nftCode,
        TvmCell indexBasisCode,
        TvmCell indexCode,
        string json,
        TvmCell platformCode
    ) public {
        _onInit4_3(nftCode, indexBasisCode, indexCode);
        _onInit4_2(json);
        _platformCode = platformCode;
    }


    // TIP 4.1
    function nftAddress(uint256 id) public view responsible override returns (address nft) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _certificateAddressByID(id);
    }

    // TIP6
    function supportsInterface(
        bytes4 interfaceID
    ) public view responsible override(CollectionBase4_3, JSONMetadataBase) returns (bool support) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} (
            CollectionBase4_3.supportsInterface(interfaceID) ||
            JSONMetadataBase.supportsInterface(interfaceID)
        );
    }


    function onMint(uint256 id, address owner, address manager, address creator) public onlyCertificateByID(id) {
        _reserve();
        _onMint(id, msg.sender, owner, manager, creator);
        IOwner(owner).onMinted{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED,
            bounce: false
        }(id, msg.sender, owner, manager, creator);
    }

    function onBurn(uint256 id, address owner, address manager) public onlyCertificateByID(id) {
        _reserve();
        _onBurn(id, msg.sender, owner, manager);
        IOwner(owner).onBurt{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED,
            bounce: false
        }(id, msg.sender, owner, manager);
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
                _root: address(this),
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
