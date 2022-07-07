pragma ton-solidity >= 0.61.2;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../interfaces/outer/IOwner.sol";
import "../utils/TransferUtils.sol";
import "./Addressable.sol";

import "tip4/contracts/implementation/4_2/JSONMetadataBase.sol";
import "tip4/contracts/implementation/4_3/CollectionBase4_3.sol";


abstract contract Collection is CollectionBase4_3, JSONMetadataBase, Addressable, TransferUtils {

    modifier onlyCertificate(uint256 id) {
        address nft = _certificateAddress(id);
        require(msg.sender == nft, 69);
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
        _root = address(this);
        _platformCode = platformCode;
    }


    // TIP 4.1
    function nftAddress(uint256 id) public view responsible override returns (address nft) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _certificateAddress(id);
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

    function certificateAddressByPath(string path) public view responsible returns (address nft) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _certificateAddressByPath(path);
    }


    function onMint(uint256 id, address owner, address manager) public onlyCertificate(id) {
        _reserve();
        address creator = _root;
        _onMint(id, msg.sender, owner, manager, creator);
        IOwner(owner).onMint{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED,
            bounce: false
        }(id, msg.sender, owner, manager, creator);
    }

    function onBurn(uint256 id, address owner, address manager) public onlyCertificate(id) {
        _reserve();
        _onBurn(id, msg.sender, owner, manager);
        IOwner(owner).onBurn{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED,
            bounce: false
        }(id, msg.sender, owner, manager);
    }

}
