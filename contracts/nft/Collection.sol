pragma ton-solidity >= 0.61.2;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../abstract/Addressable.sol";
import "../interfaces/nft/ICollection.sol";
import "../interfaces/outer/INFTOwner.sol";
import "../interfaces/IUpgradable.sol";
import "../utils/TransferUtils.sol";

import "@broxus/contracts/contracts/utils/CheckPubKey.sol";
import "tip4/contracts/implementation/4_2/JSONMetadataBase.sol";
import "tip4/contracts/implementation/4_3/CollectionBase4_3.sol";


contract Collection is CollectionBase4_3, JSONMetadataBase, ICollection, IUpgradable, Addressable, TransferUtils, CheckPubKey {

    event AlreadyMinted(address nft);

    modifier onlyNFT(uint256 id) {
        address nft = _nftAddressThis(id);
        require(msg.sender == nft, 69);
        _;
    }

    constructor(
        TvmCell nftCode,
        TvmCell indexBasisCode,
        TvmCell indexCode,
        string json,
        address root,
        TvmCell platformCode
    ) public checkPubKey {
        tvm.accept();
        _onInit4_3(nftCode, indexBasisCode, indexCode);
        _onInit4_2(json);
        _root = root;
        _platformCode = platformCode;
    }


    // TIP 4.1
    function nftAddress(uint256 id) public view responsible override returns (address nft) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _nftAddressThis(id);
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

    function nftAddressByPath(string path) public view responsible override returns (address nft) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _nftAddressByPath(address(this), path);
    }


    function mint(string path, address owner, uint32 expireTime, uint32 expiringTimeRange) public override onlyRoot {
        uint256 id = tvm.hash(path);
        TvmCell stateInit = _buildNftStateInit(address(this), id);
        TvmCell params = abi.encode(path, owner, _root, expireTime, expiringTimeRange, _indexCode);
        new Platform{
            stateInit: stateInit,
            value: 0,
            flag: MsgFlag.REMAINING_GAS,
            bounce: true
        }(_nftCode, params, address(0));
    }

    function onMint(uint256 id, address owner, address manager) public override onlyNFT(id) {
        _reserve();
        address creator = _root;
        _onMint(id, msg.sender, owner, manager, creator);
        IOwner(owner).onMint{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED,
            bounce: false
        }(id, msg.sender, owner, manager, creator);
    }

    function onBurn(uint256 id, address owner, address manager) public override onlyNFT(id) {
        _reserve();
        _onBurn(id, msg.sender, owner, manager);
        IOwner(owner).onBurn{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED,
            bounce: false
        }(id, msg.sender, owner, manager);
    }


    function _nftAddressThis(uint256 id) private inline view returns (address) {
        return _nftAddress(address(this), id);
    }

    onBounce(TvmSlice body) external pure {
        uint32 functionId = body.decode(uint32);
        if (functionId == tvm.functionId(mint)) {
            // already minted
            emit AlreadyMinted(msg.sender);
        }
    }


    function upgrade(TvmCell code) public internalMsg override onlyRoot {
        emit CodeUpgraded();
        TvmCell data = abi.encode("values");  // todo values
        tvm.setcode(code);
        tvm.setCurrentCode(code);
        onCodeUpgrade(data);
    }

    function onCodeUpgrade(TvmCell input) private {
        // todo
    }

}
