pragma ton-solidity >= 0.61.2;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../abstract/Addressable.sol";
import "../interfaces/nft/ICollection.sol";
import "../interfaces/IUpgradable.sol";
import "../utils/ErrorCodes.sol";
import "../utils/Gas.sol";
import "../utils/TransferUtils.sol";

import "@broxus/contracts/contracts/utils/CheckPubKey.sol";


contract Collection is ICollection, IUpgradable, Addressable, TransferUtils, CheckPubKey {

    event NftCreated(uint256 id, address nft, address owner, address manager, address creator);
    event NftBurned(uint256 id, address nft, address owner, address manager);


    uint64 public _totalSupply;
    TvmCell public _nftCode;


    modifier onlyNFT(uint256 id) {
        address nft = _nftAddress(address(this), id);
        require(msg.sender == nft, 69);
        _;
    }

    constructor(address root, TvmCell platformCode, TvmCell nftCode) public checkPubKey {
        tvm.accept();
        _root = root;
        _platformCode = platformCode;
        _nftCode = nftCode;
    }


    function totalSupply() public view responsible override returns (uint128 count) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _totalSupply;
    }

    function nftCode() public view responsible override returns (TvmCell code) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _nftCode;
    }

    function nftCodeHash() public view responsible override returns (uint256 codeHash) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} tvm.hash(_nftCode);
    }

    function nftAddress(uint256 id) public view responsible override returns (address nft) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _nftAddress(address(this), id);
    }

    function nftAddressByName(string name) public view responsible override returns (address nft) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _nftAddressByName(address(this), name);
    }


    function mint(string name, address owner, uint32 expireTime, uint32 expiringTimeRange) public override onlyRoot {
        uint256 id = tvm.hash(name);
        TvmCell stateInit = _buildNftStateInit(address(this), id);
        TvmCell params = abi.encode(name, owner, _root, expireTime, expiringTimeRange);
        address nft = new Platform{
            stateInit: stateInit,
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED,  // todo test with emit
            bounce: true
        }(_nftCode, params, address(0));
        emit NftCreated(id, nft, owner, _root, owner);
        _totalSupply++;
    }

    function onNftBurn(uint256 id, address owner, address manager) public override onlyNFT(id) {
        _reserve();
        _totalSupply--;
        emit NftBurned(id, msg.sender, owner, manager);
        owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false});
    }


    onBounce(TvmSlice body) external {
        uint32 functionId = body.decode(uint32);
        if (functionId == tvm.functionId(mint)) {
            _totalSupply--;  // already minted
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
