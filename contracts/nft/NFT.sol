pragma ton-solidity >= 0.61.2;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../abstract/Addressable.sol";
import "../interfaces/nft/ICollection.sol";
import "../interfaces/nft/INFT.sol";
import "../interfaces/outer/INFTCallback.sol";
import "../interfaces/outer/IOwner.sol";
import "../utils/TransferUtils.sol";


contract NFT is INFT, Addressable, TransferUtils {

    event NftCreated(uint256 id, address owner, address manager, address collection);
    event OwnerChanged(address oldOwner, address newOwner);
    event ManagerChanged(address oldManager, address newManager);
    event NftBurned(uint256 id, address owner, address manager, address collection);


    uint256 public _id;
    address public _collection;

    address public _owner;
    address public _manager;

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
        (_name, _owner, _manager, _expireTime, _expiringTimeRange) =
            abi.decode(initialParams, (string, address, address, uint32, uint32));
        _domain = _domainAddress(_name);
        emit NftCreated(_id, _owner, _manager, _collection);
    }


    function getInfo() public view responsible override returns (uint256 id, address owner, address manager, address collection) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} (_id, _owner, _manager, _collection);
    }

    function changeOwner(address newOwner, address sendGasTo, mapping(address => CallbackParams) callbacks) public override onlyManager notExpiring {
        _reserve();
        _changeOwner(newOwner);
        _sendCallbacks(sendGasTo, callbacks);
    }

    function changeManager(address newManager, address sendGasTo, mapping(address => CallbackParams) callbacks) public override onlyManager notExpiring {
        _reserve();
        _changeManager(newManager);
        _sendCallbacks(sendGasTo, callbacks);
        // todo expiring
    }

    function transfer(address to, address sendGasTo, mapping(address => CallbackParams) callbacks) public override onlyManager notExpiring {
//        _reserve();
//        _changeOwner(to);  // todo !!!
//        _changeManager(to);
//        _sendCallbacks(sendGasTo, callbacks);
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
        IOwner(_owner).onUnresevre{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED,
            bounce: false
        }(_name, expireTime);
    }

    function burn() public override onlyDomain {
        emit NftBurned(_id, _owner, _manager, _collection);
        ICollection(_collection).onNftBurn{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.DESTROY_IF_ZERO,
            bounce: false
        }(_id, _owner, _manager);
    }


    function _changeOwner(address newOwner) private {
        emit OwnerChanged(_owner, newOwner);
        _owner = newOwner;
    }

    function _changeManager(address newManager) private {
        emit ManagerChanged(_manager, newManager);
        _manager = newManager;
    }

    function _sendCallbacks(address sendGasTo, mapping(address => CallbackParams) callbacks) private view {
        optional(TvmCell) ownerPayload;
        for ((address recipient, CallbackParams params) : callbacks) {
            if (recipient != sendGasTo) {
                INFTCallback(recipient).callback{
                    value: params.value,
                    flag: 0,
                    bounce: false
                }(_id, _owner, _manager, _collection, params.payload);
            } else {
                ownerPayload.set(params.payload);
            }
        }
        if (ownerPayload.hasValue()) {
            INFTCallback(sendGasTo).callback{
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED,
                bounce: false
            }(_id, _owner, _manager, _collection, ownerPayload.get());
        } else {
            sendGasTo.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false});
        }
    }


    // todo update

}
