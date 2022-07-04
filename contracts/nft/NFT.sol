pragma ton-solidity >= 0.61.2;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../abstract/Addressable.sol";
import "../interfaces/nft/ICollection.sol";
import "../interfaces/nft/INFT.sol";
import "../interfaces/outer/INFTCallback.sol";
import "../interfaces/outer/IOwner.sol";
import "../utils/Gas.sol";

import "tip4/contracts/implementation/4_2/JSONMetadataBase.sol";
import "tip4/contracts/implementation/4_3/NFTBase4_3.sol";


contract NFT is NFTBase4_3, JSONMetadataBase, INFT, Addressable {

    uint256 public _id;
    address public _collection;

    string public _name;
    address public _domain;
    uint32 public _expireTime;
    uint32 public _expiringTimeRange;


    modifier onlyManager() {
        require(msg.sender == _manager, 69);
        _;
    }

    modifier onlyDomain() {
        require(msg.sender == _domain, 69);
        _;
    }

    modifier notExpiring() {
        require(now < _expireTime - _expiringTimeRange, 69);
        _;
    }


    function onCodeUpgrade(TvmCell input) private {
        tvm.resetStorage();
        TvmSlice slice = input.toSlice();
        (_root, /*type*/, /*remainingGasTo*/) = slice.decode(address, uint8, address);
        _platformCode = slice.loadRef();

        TvmCell initialData = slice.loadRef();
        (_id, _collection) = abi.decode(initialData, (uint256, address));
        TvmCell initialParams = slice.loadRef();
        (_name, _owner, _manager, _expireTime, _expiringTimeRange, _indexCode) =
            abi.decode(initialParams, (string, address, address, uint32, uint32, TvmCell));
        _domain = _domainAddress(_name);

        _onInit4_3(_owner, _manager, _indexCode);
        _onInit4_2("");  // todo generate JSON
        ICollection(_collection).onMint{
            value: Gas.ON_MINT_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false
        }(_id, _owner, _manager);
    }


    // TIP 4.1
    function changeOwner(address newOwner, address sendGasTo, mapping(address => CallbackParams) callbacks) public override onlyManager notExpiring {
        super.changeOwner(newOwner, sendGasTo, callbacks);
    }

    // TIP 4.1
    function changeManager(address newManager, address sendGasTo, mapping(address => CallbackParams) callbacks) public override onlyManager notExpiring {
        super.changeManager(newManager, sendGasTo, callbacks);_reserve();
        // todo expiring
    }

    // TIP 4.1
    function transfer(address to, address sendGasTo, mapping(address => CallbackParams) callbacks) public override onlyManager notExpiring {
        super.transfer(to, sendGasTo, callbacks);
        // todo expiring
    }

    // TIP 6
    function supportsInterface(
        bytes4 interfaceID
    ) public view responsible override(NFTBase4_3, JSONMetadataBase) returns (bool support) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} (
            NFTBase4_3.supportsInterface(interfaceID) ||
            JSONMetadataBase.supportsInterface(interfaceID)
        );
    }

    function prolong(uint32 expireTime) public override onlyDomain {
        _expireTime = expireTime;
        IOwner(_owner).onProlong{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED,
            bounce: false
        }(_name, expireTime);
    }

    function unreserve(address owner, uint32 expireTime) public override onlyDomain {
        _owner = owner;
        _expireTime = expireTime;
        _updateIndexes(_owner, owner, _owner);
        IOwner(_owner).onUnresevre{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED,
            bounce: false
        }(_name, expireTime);
    }

    function burn() public override onlyDomain {
        ICollection(_collection).onBurn{
            value: 0,
            flag: MsgFlag.REMAINING_GAS,
            bounce: false
        }(_id, _owner, _manager);
        _onBurn(_owner);
    }


    function _getId() internal view override returns (uint256) {
        return _id;
    }

    function _getCollection() internal view override returns (address) {
        return _collection;
    }


    // todo update

}
